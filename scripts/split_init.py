#!/usr/bin/env python3

"""Split kickstart's monolithic init.lua into modular Lua files.

This script is intentionally repo-specific. It understands the current section
markers in the single-file init.lua and emits the modular tree into a separate
output root:

* init.lua loader plus the examples block
* one Lua file per core section

Use --write to update files and --check to verify them.
"""

from __future__ import annotations

import argparse
import difflib
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import cast


@dataclass(frozen=True)
class SectionSpec:
    number: int
    filename: str
    module: str
    uses_gh: bool = False


@dataclass(frozen=True)
class CliArgs:
    source: str
    output_root: str
    write: bool
    check: bool


FILE_SECTION_SPECS = [
    SectionSpec(1, "section_01_foundation.lua", "kickstart.sections.section_01_foundation"),
    SectionSpec(2, "section_02_plugin_manager.lua", "kickstart.sections.section_02_plugin_manager"),
    SectionSpec(3, "section_03_ui.lua", "kickstart.sections.section_03_ui", uses_gh=True),
    SectionSpec(4, "section_04_search.lua", "kickstart.sections.section_04_search", uses_gh=True),
    SectionSpec(5, "section_05_lsp.lua", "kickstart.sections.section_05_lsp", uses_gh=True),
    SectionSpec(6, "section_06_formatting.lua", "kickstart.sections.section_06_formatting", uses_gh=True),
    SectionSpec(7, "section_07_completion.lua", "kickstart.sections.section_07_completion", uses_gh=True),
    SectionSpec(8, "section_08_treesitter.lua", "kickstart.sections.section_08_treesitter", uses_gh=True),
]

INLINE_SECTION_SPECS = [
    SectionSpec(9, "section_09_examples.lua", "kickstart.sections.section_09_examples"),
]

ALL_SECTION_SPECS = [*FILE_SECTION_SPECS, *INLINE_SECTION_SPECS]

SECTION_HEADER_RE = re.compile(r"^-- SECTION (?P<number>\d+): (?P<title>.+)$")
SEPARATOR_LINE = "-- ============================================================"
GH_HELPER = [
    "---Because most plugins are hosted on GitHub, you can use the helper",
    "---function to have less repetition in the following sections.",
    "---@param repo string",
    "---@return string",
    "local function gh(repo) return 'https://github.com/' .. repo end",
]


def fail(message: str) -> None:
    raise SystemExit(message)


def read_lines(path: Path) -> list[str]:
    try:
        return path.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError as exc:
        fail(f"missing source file: {path}")
        raise exc


def render(lines: list[str]) -> str:
    text = "\n".join(lines)
    if not text.endswith("\n"):
        text += "\n"
    return text


def find_section_headers(lines: list[str]) -> dict[int, int]:
    headers: dict[int, int] = {}
    for idx, line in enumerate(lines):
        match = SECTION_HEADER_RE.match(line)
        if match:
            number = int(match.group("number"))
            if number in headers:
                fail(f"duplicate section marker {number}")
            headers[number] = idx
    return headers


def section_start_index(lines: list[str], header_idx: int) -> int:
    start_idx = header_idx - 1
    if start_idx < 0 or lines[start_idx] != SEPARATOR_LINE:
        fail(f"section header at line {header_idx + 1} is missing its leading separator")
    return start_idx


def section_end_index(lines: list[str], next_header_idx: int | None) -> int:
    if next_header_idx is None:
        for idx in range(len(lines) - 1, -1, -1):
            if lines[idx] == "end":
                return idx
        fail("could not find the final section end")

    assert next_header_idx is not None
    end_idx: int = next_header_idx - 2
    if end_idx < 0:
        fail("invalid section boundary before the next header")
    return end_idx


def build_section_file(section_lines: list[str], uses_gh: bool) -> list[str]:
    do_idx = -1
    for idx, line in enumerate(section_lines):
        if line == "do":
            do_idx = idx
            break

    if do_idx < 0:
        fail("section did not contain a top-level do block")

    end_idx: int = -1
    for idx in range(len(section_lines) - 1, do_idx, -1):
        if section_lines[idx] == "end":
            end_idx = idx
            break

    if end_idx < 0:
        fail("section did not contain a matching end block")

    header = section_lines[:do_idx]
    body = section_lines[do_idx : end_idx + 1]

    if uses_gh:
        return [*header, "", *GH_HELPER, "", *body]

    return [*header, *body]


def build_loader_lines() -> list[str]:
    lines = ["-- Load the split sections in order.", ""]
    lines.extend([f"require '{spec.module}'" for spec in FILE_SECTION_SPECS])
    return lines


def build_root_init(
    prelude: list[str], loader_lines: list[str], inline_sections: list[list[str]], postlude: list[str]
) -> list[str]:
    root = list(prelude)
    root = [line.replace("Single-file", "Modular") for line in root]
    if root and root[-1] != "":
        root.append("")
    root.extend(loader_lines)

    if inline_sections:
        root.append("")
        for idx, section_lines in enumerate(inline_sections):
            root.extend(section_lines)
            if idx + 1 < len(inline_sections):
                root.append("")

    root.extend(postlude)
    return root


def build_outputs(source_lines: list[str]) -> dict[Path, list[str]]:
    headers = find_section_headers(source_lines)
    expected_numbers = [spec.number for spec in ALL_SECTION_SPECS]
    if sorted(headers) != expected_numbers:
        fail(f"section markers do not match expected set: found {sorted(headers)}, expected {expected_numbers}")

    header_positions = [headers[number] for number in expected_numbers]
    if header_positions != sorted(header_positions):
        fail("section markers are out of order")

    first_header_idx = min(headers.values())
    first_section_start_idx = section_start_index(source_lines, first_header_idx)
    prelude = source_lines[:first_section_start_idx]

    last_section_end_idx = section_end_index(source_lines, None)
    postlude = source_lines[last_section_end_idx + 1 :]

    inline_sections: list[list[str]] = []
    for spec in INLINE_SECTION_SPECS:
        header_idx = headers[spec.number]
        start_idx = section_start_index(source_lines, header_idx)
        end_idx = section_end_index(source_lines, None)
        section_lines = source_lines[start_idx : end_idx + 1]
        inline_sections.append(section_lines)

    outputs: dict[Path, list[str]] = {
        Path("init.lua"): build_root_init(prelude, build_loader_lines(), inline_sections, postlude),
    }

    for idx, spec in enumerate(FILE_SECTION_SPECS):
        header_idx = headers[spec.number]
        next_header_idx = (
            headers[FILE_SECTION_SPECS[idx + 1].number]
            if idx + 1 < len(FILE_SECTION_SPECS)
            else headers[INLINE_SECTION_SPECS[0].number]
        )
        start_idx = section_start_index(source_lines, header_idx)
        end_idx = section_end_index(source_lines, next_header_idx)
        section_lines = source_lines[start_idx : end_idx + 1]
        outputs[Path("lua") / "kickstart" / "sections" / spec.filename] = build_section_file(
            section_lines, spec.uses_gh
        )

    return outputs


def write_outputs(outputs: dict[Path, list[str]], root: Path) -> None:
    for rel_path, lines in outputs.items():
        path = root / rel_path
        path.parent.mkdir(parents=True, exist_ok=True)
        _ = path.write_text(render(lines), encoding="utf-8")


def check_outputs(outputs: dict[Path, list[str]], root: Path) -> int:
    exit_code = 0
    for rel_path, lines in outputs.items():
        path = root / rel_path
        expected = render(lines)
        if not path.exists():
            print(f"MISSING {rel_path}")
            exit_code = 1
            continue

        current = path.read_text(encoding="utf-8")
        if current != expected:
            print(f"DIFF {rel_path}")
            diff = difflib.unified_diff(
                current.splitlines(),
                expected.splitlines(),
                fromfile=str(rel_path),
                tofile=f"expected/{rel_path}",
                lineterm="",
            )
            for line in diff:
                print(line)
            exit_code = 1
    return exit_code


def parse_args() -> CliArgs:
    parser = argparse.ArgumentParser(description=__doc__)
    _ = parser.add_argument("--source", default="init.lua", help="Path to the monolithic init.lua source file")
    _ = parser.add_argument("--output-root", required=True, help="Directory where modular files should be written")
    mode = parser.add_mutually_exclusive_group(required=True)
    _ = mode.add_argument("--write", action="store_true", help="Write the split files to disk")
    _ = mode.add_argument("--check", action="store_true", help="Check the split files without writing")
    namespace = parser.parse_args()
    return CliArgs(
        source=cast(str, getattr(namespace, "source", "init.lua")),
        output_root=cast(str, getattr(namespace, "output_root")),
        write=cast(bool, getattr(namespace, "write", False)),
        check=cast(bool, getattr(namespace, "check", False)),
    )


def main() -> int:
    args = parse_args()
    source = Path(args.source)
    output_root = Path(args.output_root)
    outputs = build_outputs(read_lines(source))

    if args.write:
        write_outputs(outputs, output_root)
        return 0

    return check_outputs(outputs, output_root)


if __name__ == "__main__":
    sys.exit(main())
