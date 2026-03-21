#!/usr/bin/env bash

mirror_nvim_plugins() {
	local plugin_dir="$HOME/.local/share/nvim/lazy"
	local mirror_dir="/tmp/mirror/plugins"

	mkdir -p "$mirror_dir"

	find "$plugin_dir" -mindepth 1 -maxdepth 1 | while read -r full_name; do
		echo "Processing: $full_name"

		cd "$full_name" || continue

		local target_dir
		target_dir="$mirror_dir/$(basename "$full_name")"

		echo "Cloning mirror to: $target_dir"
		git clone --mirror "$(git remote get-url origin)" "$target_dir" || continue

		cd "$target_dir" || continue
		git config --bool core.bare false

		git checkout "$(git rev-parse --abbrev-ref HEAD)"
	done
}

rm -rf /tmp/mirror.zip || true
rm -rf /tmp/mirror || true
mkdir -p /tmp/mirror

git clone git@github.com:oriori1703/kickstart-modular.nvim.git /tmp/mirror/config-nvim

mirror_nvim_plugins
cp -r ~/.local/share/nvim/ /tmp/mirror/nvim-share

cd /tmp || exit 1
zip -r mirror.zip mirror
