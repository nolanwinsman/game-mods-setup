#!/usr/bin/env bash
# mods/re4hdproject.sh — installs the RE4 HD Project mod for Resident Evil 4 (2005), AppID 254700.
# Called by setup-mods.sh; expects lib/steam.sh already sourced.

RE4_APPID=254700
RE4_WINE_PREFIX="$HOME/.local/share/game-mods/wineprefixes/re4hdproject"

install_re4hdproject() {
    local exe="${1:-}"

    if [[ -z "$exe" ]]; then
        read -rp "Path to re4HDProject-setup.exe: " exe
    fi
    # Strip surrounding quotes (common when a file manager pastes a quoted path)
    # and expand a leading ~.
    exe="${exe%\"}"; exe="${exe#\"}"
    exe="${exe%\'}"; exe="${exe#\'}"
    exe="${exe/#\~/$HOME}"

    if [[ -z "$exe" || ! -f "$exe" ]]; then
        echo "ERROR: '$exe' is not a file." >&2
        return 1
    fi

    echo "==> Looking for your Resident Evil 4 (2005) Steam install (AppID $RE4_APPID)..."
    local gamedir
    if gamedir=$(find_game_dir "$RE4_APPID"); then
        echo "==> Found it: $gamedir"
    else
        echo "!! Could not auto-detect the game folder."
        read -rp "Enter your RE4 install path manually (e.g. .../steamapps/common/Resident Evil 4): " gamedir
        if [[ ! -d "$gamedir" ]]; then
            echo "ERROR: '$gamedir' is not a directory." >&2
            return 1
        fi
    fi

    ensure_wine || return 1

    cat <<EOF

The installer will open in a moment. When it asks for the game folder,
paste this exact path:

    $gamedir

EOF
    if command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$gamedir" | wl-copy && echo "(copied to clipboard via wl-copy)"
    elif command -v xclip >/dev/null 2>&1; then
        printf '%s' "$gamedir" | xclip -selection clipboard && echo "(copied to clipboard via xclip)"
    fi
    read -rp "Press Enter to launch the installer..." _

    run_installer_in_prefix "$RE4_WINE_PREFIX" "$exe"

    cat <<'EOF'

==> Installer finished.

Two things left to do in Steam (these can't be scripted — they're Steam client settings):

1. Right-click Resident Evil 4 (2005) in your Steam Library -> Properties -> General
   -> Launch Options, and set it to:

       WINEDLLOVERRIDES="dinput8=n,b" %command%

   (Required so the mod's dinput8.dll hook loads correctly under Proton.)

2. Launch the game normally through Steam. On first launch you'll get a popup
   about the EXE needing the 4GB patch — click "Yes" to patch it and let the
   game restart itself. After that you're done.

EOF
}
