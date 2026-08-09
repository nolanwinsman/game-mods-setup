#!/usr/bin/env bash
# lib/steam.sh — shared helpers for locating Steam libraries/games and running Wine.
# Sourced by mod scripts; not meant to be executed directly.

# Candidate Steam root install locations (native, flatpak, plus a manual override var).
steam_candidate_roots() {
    local roots=(
        "$HOME/.local/share/Steam"
        "$HOME/.steam/steam"
        "$HOME/.steam/root"
        "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"
    )
    [[ -n "${STEAM_ROOT:-}" ]] && roots=("$STEAM_ROOT" "${roots[@]}")
    for r in "${roots[@]}"; do
        [[ -d "$r/steamapps" ]] && echo "$r"
    done
}

# Print every Steam library path (main root + any extra libraries from libraryfolders.vdf).
steam_library_paths() {
    local root lib_vdf
    while IFS= read -r root; do
        echo "$root"
        lib_vdf="$root/steamapps/libraryfolders.vdf"
        if [[ -f "$lib_vdf" ]]; then
            # Each library entry looks like:  "path"     "/some/path"
            grep -oP '"path"\s*"\K[^"]+' "$lib_vdf" | sed 's/\\\\/\//g'
        fi
    done < <(steam_candidate_roots) | sort -u
}

# find_game_dir <appid>
# Looks for steamapps/appmanifest_<appid>.acf in every library, reads "installdir",
# and prints the absolute path to steamapps/common/<installdir> if it exists.
find_game_dir() {
    local appid="$1" lib manifest installdir
    while IFS= read -r lib; do
        manifest="$lib/steamapps/appmanifest_${appid}.acf"
        if [[ -f "$manifest" ]]; then
            installdir=$(grep -oP '"installdir"\s*"\K[^"]+' "$manifest")
            local gamedir="$lib/steamapps/common/$installdir"
            [[ -d "$gamedir" ]] && { echo "$gamedir"; return 0; }
        fi
    done < <(steam_library_paths)
    return 1
}

# ensure_wine — make sure a `wine` command is available, falling back to a
# throwaway nix shell if it's not installed system-wide. Exports $WINE_BIN.
ensure_wine() {
    if command -v wine >/dev/null 2>&1; then
        WINE_BIN="wine"
        return 0
    fi
    if command -v nix >/dev/null 2>&1; then
        echo "wine not found on PATH — falling back to 'nix shell nixpkgs#wine64' for this run." >&2
        echo "(Add wine/wineWowPackages to your NixOS configuration.nix to avoid this every time.)" >&2
        WINE_BIN="nix shell nixpkgs#wine64 -c wine"
        return 0
    fi
    echo "ERROR: wine is not installed and nix is not available to fetch it." >&2
    echo "Install it via NixOS config (environment.systemPackages = [ pkgs.wineWowPackages.stable ];)" >&2
    return 1
}

# run_installer_in_prefix <prefix_dir> <exe_path>
run_installer_in_prefix() {
    local prefix="$1" exe="$2"
    mkdir -p "$prefix"
    echo "==> Initializing Wine prefix at: $prefix (first run only, may take a moment)"
    WINEPREFIX="$prefix" WINEDLLOVERRIDES="mscoree,mshtml=" ${WINE_BIN} wineboot -u >/dev/null 2>&1 || true
    echo "==> Launching installer: $exe"
    WINEPREFIX="$prefix" ${WINE_BIN} "$exe"
}
