#!/usr/bin/env bash
# setup-mods.sh — discovers every mod script in scripts/ and asks whether to
# install each one. Each script in scripts/ is expected to:
#   1. Be named after its mod, e.g. scripts/vtmbunofficialpatch.sh
#   2. Have a "# DESC: <one-line description>" comment near the top, which
#      is shown to the user instead of the bare filename.
#   3. Define an install_<name> function matching the filename (minus .sh),
#      e.g. scripts/vtmbunofficialpatch.sh -> install_vtmbunofficialpatch
#   4. Handle its own prompts (exe path, game dir fallback, etc.) internally.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
MODS_DIR="$SCRIPT_DIR/scripts"
LIB_DIR="$SCRIPT_DIR/lib"

# Source shared helpers (find_game_dir, ensure_wine, run_installer_in_prefix, etc.)
if [[ -f "$LIB_DIR/steam.sh" ]]; then
	# shellcheck source=lib/steam.sh
	source "$LIB_DIR/steam.sh"
else
	echo "ERROR: expected $LIB_DIR/steam.sh but it wasn't found." >&2
	exit 1
fi

if [[ ! -d "$MODS_DIR" ]]; then
	echo "ERROR: mods directory '$MODS_DIR' not found." >&2
	exit 1
fi

ask_yes_no() {
	local prompt="$1" reply
	while true; do
		read -rp "$prompt [y/N] " reply
		case "$reply" in
		[Yy] | [Yy][Ee][Ss]) return 0 ;;
		"" | [Nn] | [Nn][Oo]) return 1 ;;
		*) echo "Please answer y or n." ;;
		esac
	done
}

# Extracts the "# DESC: ..." comment from a script, if present.
# Only looks at the first 20 lines so it doesn't accidentally pick up a
# DESC-looking string buried in a heredoc later in the file.
get_desc() {
	local script="$1" line
	line="$(head -n 20 "$script" | grep -m1 -E '^#[[:space:]]*DESC:[[:space:]]*' || true)"
	if [[ -n "$line" ]]; then
		sed -E 's/^#[[:space:]]*DESC:[[:space:]]*//' <<<"$line"
	fi
}

shopt -s nullglob
mod_scripts=("$MODS_DIR"/*.sh)
shopt -u nullglob

if [[ ${#mod_scripts[@]} -eq 0 ]]; then
	echo "No mod scripts found in $MODS_DIR."
	exit 0
fi

echo "Found ${#mod_scripts[@]} mod script(s) in $MODS_DIR."
echo

for script in "${mod_scripts[@]}"; do
	name="$(basename "$script" .sh)"
	func="install_${name}"
	desc="$(get_desc "$script")"

	# shellcheck source=/dev/null
	source "$script"

	if ! declare -F "$func" >/dev/null; then
		echo "!! Skipping '$name': expected function '$func' not found in $script." >&2
		echo
		continue
	fi

	if [[ -n "$desc" ]]; then
		echo "== ${name} =="
		echo "   $desc"
	else
		echo "== ${name} (no description found) =="
	fi

	if ask_yes_no "Install this mod?"; then
		if "$func"; then
			echo "==> ${name}: done."
		else
			echo "!! ${name}: install failed (exit code $?)." >&2
		fi
	else
		echo "==> Skipping ${name}."
	fi
	echo
done

echo "All done."
