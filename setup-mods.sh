#!/usr/bin/env bash
# setup-mods.sh — entrypoint for installing Windows-exe-based game mods on NixOS
# under Wine/Proton, without touching the Steam Proton prefix directly.
#
# Usage:
#   ./setup-mods.sh              walk through every registered mod, asking Y/n for each
#   ./setup-mods.sh <mod-name>   run just that one mod, no prompt
#   ./setup-mods.sh list         list registered mods
#
# Add new mods by dropping a mods/<name>.sh file that defines install_<name>(),
# then adding <name> to the MODS array and the case in run_mod() below.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

source ./lib/steam.sh

# Registry of available mods. Order here is the order they're offered in.
MODS=(re4hdproject)

usage() {
    cat <<EOF
Usage: $0                run through every mod below and ask whether to set it up
       $0 <mod-name>     set up just one mod, skipping the prompt
       $0 list           list available mods

Available mods:
  re4hdproject   Install RE4 HD Project for Resident Evil 4 (2005)
                 (will prompt you for the path to re4HDProject-setup.exe)
EOF
}

# run_mod <name> — dispatches to that mod's install function.
run_mod() {
    local mod="$1"
    case "$mod" in
        re4hdproject)
            source ./mods/re4hdproject.sh
            install_re4hdproject
            ;;
        *)
            echo "Unknown mod: $mod" >&2
            return 1
            ;;
    esac
}

# ask_yes_no <prompt> — returns 0 for yes, 1 for no/anything else. Defaults to no.
ask_yes_no() {
    local prompt="$1" ans
    read -rp "$prompt [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

if [[ "${1:-}" == "list" ]]; then
    usage
    exit 0
fi

if [[ $# -ge 1 ]]; then
    # A specific mod was named — just run it, no prompting.
    run_mod "$1"
    exit $?
fi

# No mod named: walk the whole registry and ask for each one.
echo "No mod specified — going through all available mods."
echo
for mod in "${MODS[@]}"; do
    if ask_yes_no "Set up '$mod'?"; then
        echo "==> Setting up $mod"
        run_mod "$mod" || echo "!! $mod setup failed or was cancelled." >&2
    else
        echo "==> Skipping $mod"
    fi
    echo
done
echo "Done."
