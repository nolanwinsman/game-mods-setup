#!/usr/bin/env bash
# DESC: The Unofficial Patch for Vampire The Masquerade - Bloodlines (2004)
# Called by setup-mods.sh; expects lib/steam.sh already sourced.
VTMB_APPID=2600
VTMB_WINE_PREFIX="$HOME/.local/share/game-mods/wineprefixes/vtmbunofficialpatch"

# Converts a Linux path into the Z:\ drive path Wine/Proton installers expect,
# e.g. /home/nw/Steam/... -> Z:\home\nw\Steam\...
to_wine_path() {
	local p="$1"
	printf 'Z:%s' "$p" | sed 's#/#\\#g'
}

install_vtmbunofficialpatch() {
	local exe="${1:-}"
	if [[ -z "$exe" ]]; then
		read -rp "Path to Unofficial_Patch_*.exe: " exe
	fi
	# Strip surrounding quotes (common when a file manager pastes a quoted path)
	# and expand a leading ~.
	exe="${exe%\"}"
	exe="${exe#\"}"
	exe="${exe%\'}"
	exe="${exe#\'}"
	exe="${exe/#\~/$HOME}"
	if [[ -z "$exe" || ! -f "$exe" ]]; then
		echo "ERROR: '$exe' is not a file." >&2
		return 1
	fi
	echo "==> Looking for your Vampire: The Masquerade - Bloodlines Steam install (AppID $VTMB_APPID)..."
	local gamedir
	if gamedir=$(find_game_dir "$VTMB_APPID"); then
		echo "==> Found it: $gamedir"
	else
		echo "!! Could not auto-detect the game folder."
		read -rp "Enter your VTMB install path manually (e.g. .../steamapps/common/Vampire The Masquerade - Bloodlines): " gamedir
		if [[ ! -d "$gamedir" ]]; then
			echo "ERROR: '$gamedir' is not a directory." >&2
			return 1
		fi
	fi
	echo "!! NOTE: if this is a non-English install, applying the patch will revert text/voice to English."
	ensure_wine || return 1

	local gamedir_win
	gamedir_win="$(to_wine_path "$gamedir")"

	cat <<EOF
The installer will open in a moment. When it asks for the destination
folder, its file browser runs inside Wine, so your Linux path needs to
be given as a Windows-style path with a Z: drive prefix. Paste this
exact path (select your patch options as desired on the following
screens):
    $gamedir_win

(If the installer's Browse dialog instead shows a Z: drive you can
navigate through, that works too — just click down into the matching
folders instead of typing/pasting.)
EOF
	if command -v wl-copy >/dev/null 2>&1; then
		printf '%s' "$gamedir_win" | wl-copy && echo "(copied to clipboard via wl-copy)"
	elif command -v xclip >/dev/null 2>&1; then
		printf '%s' "$gamedir_win" | xclip -selection clipboard && echo "(copied to clipboard via xclip)"
	fi
	read -rp "Press Enter to launch the installer..." _
	run_installer_in_prefix "$VTMB_WINE_PREFIX" "$exe"
	cat <<'EOF'
==> Installer finished.
The patch installs into a subfolder (Unofficial_Patch) rather than
overwriting the base game, so a couple of things need to be set up:
1. Right-click Vampire: The Masquerade - Bloodlines in your Steam Library
   -> Properties -> General -> Launch Options, and set it to:
       -game Unofficial_Patch
   (Required so the game actually loads the patched content instead of
   vanilla. Omit this — or use a different -game value — if you'd rather
   run a different patch profile the installer created.)
2. In Steam (and GOG Galaxy if applicable), disable auto-updates for the
   game. An auto-update can silently overwrite/break the patch.
3. Your old saves were automatically moved to save/incompatible. Start a
   NEW game after patching — old saves won't work with the patched files.
4. If you get a "failed to find Steam" error on launch, copy steam.dll
   from the game's root folder into the Unofficial_Patch subfolder.
5. If the game still won't run under Proton/Wine after all this, try
   launching Loader.exe from the game folder directly instead of the
   normal Steam shortcut — the patch notes call this out as the
   go-to fallback for Linux.
6. If you see an in-game error about "an important Python script has
   not been compiled correctly" / "playing inside a Linux Wine
   environment without running from Loader.exe", that's telling you to
   launch via Loader.exe (see #5) instead of the game's normal EXE.
EOF
}
