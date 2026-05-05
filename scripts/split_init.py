#!/usr/bin/env python3

"""Split kickstart's monolithic init.lua into modular Lua files.

This script is intentionally repo-specific. It understands the current section
markers in the single-file init.lua and emits the modular tree into a separate
output root:

* init.lua loader
* one Lua file per core section (options, keymaps, pack, plugins)
* each generated file includes its original section header at the top

Use --write to update files and --check to verify them.
"""

from __future__ import annotations

import argparse
import difflib
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import NoReturn, cast


@dataclass(frozen=True)
class CliArgs:
    source: str
    output_root: str
    write: bool
    check: bool


@dataclass(frozen=True)
class SectionHeader:
    title: str
    description: str


SECTION_HEADER_RE = re.compile(r"^-- SECTION (?P<number>\d+): (?P<title>.+)$")
SECTION_DESCRIPTION_RE = re.compile(r"^-- (?P<description>.+)$")
SEPARATOR_LINE = "-- ============================================================"
GH_HELPER = [
    "---Because most plugins are hosted on GitHub, you can use the helper",
    "---function to have less repetition in the following sections.",
    "---@param repo string",
    "---@return string",
    "local function gh(repo) return 'https://github.com/' .. repo end",
]


@dataclass(frozen=True)
class ModuleSpec:
    number: int
    path: Path
    module: str
    uses_gh: bool = False


FILE_SPECS = [
    ModuleSpec(1, Path("lua/options.lua"), "options"),
    ModuleSpec(2, Path("lua/keymaps.lua"), "keymaps"),
    ModuleSpec(3, Path("lua/pack.lua"), "pack"),
    ModuleSpec(4, Path("lua/kickstart/plugins/ui.lua"), "kickstart.plugins.ui", uses_gh=True),
    ModuleSpec(5, Path("lua/kickstart/plugins/search.lua"), "kickstart.plugins.search", uses_gh=True),
    ModuleSpec(6, Path("lua/kickstart/plugins/lsp.lua"), "kickstart.plugins.lsp", uses_gh=True),
    ModuleSpec(7, Path("lua/kickstart/plugins/formatting.lua"), "kickstart.plugins.formatting", uses_gh=True),
    ModuleSpec(8, Path("lua/kickstart/plugins/completion.lua"), "kickstart.plugins.completion", uses_gh=True),
    ModuleSpec(9, Path("lua/kickstart/plugins/treesitter.lua"), "kickstart.plugins.treesitter", uses_gh=True),
]

ALL_SECTION_NUMBERS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]


def fail(message: str) -> NoReturn:
    raise SystemExit(message)


def read_lines(path: Path) -> list[str]:
    try:
        return path.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        fail(f"missing source file: {path}")


def render(lines: list[str]) -> str:
    text = "\n".join(lines)
    if not text.endswith("\n"):
        text += "\n"
    return text


def parse_section_headers(lines: list[str]) -> dict[int, SectionHeader]:
    headers: dict[int, SectionHeader] = {}
    for idx, line in enumerate(lines):
        match = SECTION_HEADER_RE.match(line)
        if match:
            number = int(match.group("number"))
            title = match.group("title")
            description = ""
            if idx + 1 < len(lines):
                desc_match = SECTION_DESCRIPTION_RE.match(lines[idx + 1])
                if desc_match:
                    description = desc_match.group("description")
            if number in headers:
                fail(f"duplicate section marker {number}")
            headers[number] = SectionHeader(title=title, description=description)
    return headers


def make_header(number: int, header: SectionHeader) -> list[str]:
    result = [
        SEPARATOR_LINE,
        f"-- SECTION {number}: {header.title}",
        f"-- {header.description}",
        SEPARATOR_LINE,
        "",
    ]
    return result


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

    end_idx: int = next_header_idx - 2
    if end_idx < 0:
        fail("invalid section boundary before the next header")
    return end_idx


def section_body(lines: list[str]) -> list[str]:
    do_idx = -1
    end_idx = -1
    for idx, line in enumerate(lines):
        if line == "do" and do_idx < 0:
            do_idx = idx

    if do_idx < 0:
        fail("section did not contain a top-level do block")

    for idx in range(len(lines) - 1, do_idx, -1):
        if lines[idx] == "end":
            end_idx = idx
            break

    if end_idx < 0:
        fail("section did not contain a matching end block")

    return lines[do_idx + 1 : end_idx]


def dedent_block(lines: list[str]) -> list[str]:
    dedented: list[str] = []
    for line in lines:
        if line.startswith("  "):
            dedented.append(line[2:])
        else:
            dedented.append(line)
    return dedented


def build_section_module(lines: list[str], uses_gh: bool) -> list[str]:
    body = dedent_block(section_body(lines))
    if uses_gh:
        return [*GH_HELPER, "", *body]
    return body


def build_plugin_loader() -> list[str]:
    lines = ["-- Load plugin modules in order.", ""]
    lines.extend([f"require '{spec.module}'" for spec in FILE_SPECS[3:]])
    return lines


def build_root_init(prelude: list[str], postlude: list[str]) -> list[str]:
    root = list(prelude)
    if root and root[-1] != "":
        root.append("")

    root.extend(
        [
            "-- [[ Setting options ]]",
            "require 'options'",
            "",
            "-- [[ Basic Keymaps ]]",
            "require 'keymaps'",
            "",
            "-- [[ Set up vim.pack ]]",
            "require 'pack'",
            "",
            "-- [[ Configure and install plugins ]]",
            "require 'kickstart.plugins'",
        ]
    )
    root.extend(postlude)
    return root


def build_outputs(source_lines: list[str]) -> dict[Path, list[str]]:
    headers = find_section_headers(source_lines)
    section_headers = parse_section_headers(source_lines)
    expected_numbers = ALL_SECTION_NUMBERS
    if sorted(headers) != expected_numbers:
        fail(f"section markers do not match expected set: found {sorted(headers)}, expected {expected_numbers}")

    header_positions = [headers[number] for number in expected_numbers]
    if header_positions != sorted(header_positions):
        fail("section markers are out of order")

    first_header_idx = min(headers.values())
    first_section_start_idx = section_start_index(source_lines, first_header_idx)
    prelude = source_lines[:first_section_start_idx]

    section_lines: list[list[str]] = []
    for i, number in enumerate(expected_numbers):
        next_idx = headers[expected_numbers[i + 1]] if i + 1 < len(expected_numbers) else None
        start = section_start_index(source_lines, headers[number])
        end = section_end_index(source_lines, next_idx)
        section_lines.append(source_lines[start : end + 1])

    spec_by_number = {spec.number: spec for spec in FILE_SPECS}
    outputs: dict[Path, list[str]] = {
        Path("init.lua"): build_root_init(prelude, source_lines[section_end_index(source_lines, None) + 1 :]),
        Path("lua/kickstart/plugins/init.lua"): [*build_plugin_loader(), "", *make_header(10, section_headers[10]), *build_section_module(section_lines[9], False)],
    }

    for i, number in enumerate(expected_numbers[:9]):
        spec = spec_by_number[number]
        outputs[spec.path] = [*make_header(number, section_headers[number]), *build_section_module(section_lines[i], spec.uses_gh)]

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
