#!/usr/bin/env bash
# Build the Windows, Mac and Linux download zips for the site from the Quickpad app repo.
#
#   tools/build-downloads.sh <path-to-quickpad-app-repo> [git-ref]     (ref defaults to main)
#
# Files are read from the git ref with `git show`, never from the app repo's working tree, so whatever branch is
# checked out there doesn't matter and nothing in it is changed. Output goes to download/ next to index.html:
#   quickpad-<version>-windows.zip   Quickpad/quickpad.py, install-windows.bat (CRLF), assets/Quickpad.ico, READ-ME.txt (CRLF)
#   quickpad-<version>-mac.zip       Quickpad/quickpad.py, install-mac.command (executable), assets/Quickpad.icns, READ-ME.txt
#   quickpad-<version>-linux.zip     Quickpad/quickpad.py, install-linux.sh, install-mint.sh, install-omarchy.sh, READ-ME.txt
# The zips are reproducible: same ref in, same bytes out (fixed timestamps = the commit's time, sorted entries, no
# extra attributes). At the end it prints the size and SHA-256 of each file for the DOWNLOADS object in index.html.
set -euo pipefail

APP="${1:?usage: tools/build-downloads.sh <path-to-quickpad-app-repo> [git-ref]}"
REF="${2:-main}"
SITE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$SITE/download"
export TZ=UTC LC_ALL=C

git -C "$APP" rev-parse --verify -q "$REF^{commit}" >/dev/null || { echo "No such ref in $APP: $REF" >&2; exit 1; }
COMMIT="$(git -C "$APP" rev-parse "$REF^{commit}")"
STAMP="$(git -C "$APP" log -1 --format=%cd --date=format:%Y%m%d%H%M.%S "$COMMIT")"
VERSION="$(git -C "$APP" show "$COMMIT:quickpad.py" | sed -n 's/^VERSION = "\([^"]*\)".*/\1/p' | head -1)"
[ -n "$VERSION" ] || { echo "Couldn't read VERSION from quickpad.py at $REF" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

app_file() {  # app_file <repo path> <dest> <mode>
  git -C "$APP" show "$COMMIT:$1" > "$2"
  chmod "$3" "$2"
}
crlf() { sed -i 's/\r$//; s/$/\r/' "$1"; }

make_zip() {  # make_zip <platform>  (zips $WORK/<platform>/Quickpad)
  local dir="$WORK/$1" zipname="quickpad-$VERSION-$1.zip"
  find "$dir" -exec touch -h -t "$STAMP" {} +
  rm -f "$OUT/$zipname"
  (cd "$dir" && find Quickpad -type f | sort | zip -q -X -D -9 "$OUT/$zipname" -@)
  echo "$zipname"
}

mkdir -p "$OUT"

# ---- Windows
D="$WORK/windows/Quickpad"; mkdir -p "$D"
app_file quickpad.py "$D/quickpad.py" 644
app_file install-windows.bat "$D/install-windows.bat" 644
crlf "$D/install-windows.bat"   # cmd.exe mis-handles labels/goto in LF-only batch files
mkdir -p "$D/assets"; app_file assets/Quickpad.ico "$D/assets/Quickpad.ico" 644   # Start Menu shortcut icon
cat > "$D/READ-ME.txt" <<EOF
Quickpad $VERSION for Windows
=============================

1. Unzip first. Right-click the downloaded zip, choose "Extract All...", then "Extract".
   (Running the installer from inside the zip doesn't work: it needs quickpad.py next to it.)

2. Open the extracted Quickpad folder and double-click install-windows.bat.
   If Windows says "Windows protected your PC", click "More info", then "Run anyway".
   That's normal for a small app that isn't registered with Microsoft yet. You don't need
   "Run as administrator".

3. Python. Quickpad runs on Python, which is free. If it isn't installed, the installer
   installs it for you, then asks you to close the window and double-click
   install-windows.bat again. Python is installed just for your account, so no admin
   password is needed.
   If that fails, install Python 3.12 from https://www.python.org/downloads/windows/ :
   on the first screen tick "Add python.exe to PATH", then run install-windows.bat again.

4. The installer then sets up dictation (a few minutes, needs the internet). If Windows
   asks, let Python use the microphone: Settings > Privacy & security > Microphone >
   "Let desktop apps access your microphone". If dictation can't be set up, Quickpad
   still works and Settings > Dictation can try again later.

5. Quickpad opens. Next time, find "Quickpad" in the Start menu.

Where is Settings? It's a button at the top of the Quickpad panel itself (the small window
with your buttons): Edit buttons, Settings, Back up..., Restore.... If the panel has rolled
up into a thin bar, click the bar to open it, or right-click it for Settings.

Options (run from a Command Prompt in the Quickpad folder):
   install-windows.bat --autostart       also start Quickpad when you log in
   install-windows.bat --no-dictation    skip dictation

Updates arrive inside Quickpad: click "Check for updates" at the bottom of the panel.
Every update is signed, and Quickpad refuses one that isn't.

https://quickpad.praxentislabs.com.au
EOF
crlf "$D/READ-ME.txt"
WIN_ZIP="$(make_zip windows)"

# ---- Mac
D="$WORK/mac/Quickpad"; mkdir -p "$D"
app_file quickpad.py "$D/quickpad.py" 644
app_file install-mac.command "$D/install-mac.command" 755
mkdir -p "$D/assets"; app_file assets/Quickpad.icns "$D/assets/Quickpad.icns" 644   # the .app's icon
cat > "$D/READ-ME.txt" <<EOF
Quickpad $VERSION for Mac
=========================

1. Safari unzips the download for you into a "Quickpad" folder in Downloads.
   (Other browsers: double-click the zip.)

2. Python. Quickpad runs on Python with Tk 8.6, which is free. Apple's built-in python3
   is too old. Either:
   - install Python 3.12 or newer from https://www.python.org/downloads/macos/ , then open
     Applications > Python 3.x and double-click "Install Certificates.command"; or
   - if you already use Homebrew, skip this: the installer runs "brew install python-tk".

3. Install. Open Terminal (Applications > Utilities > Terminal), paste this line and
   press Return:

       bash ~/Downloads/Quickpad/install-mac.command

   (Double-clicking install-mac.command also works, but macOS usually blocks scripts
   downloaded from the internet. If it does: System Settings > Privacy & Security, scroll
   down, click "Open Anyway".)

   It installs to ~/Applications/Quickpad.app and sets up dictation (a few minutes, needs
   the internet). Add --no-dictation to the end of the line to skip dictation.

4. One-time permission: macOS must allow Quickpad to type for you.
   System Settings > Privacy & Security > Accessibility: turn on Quickpad (and Terminal
   if you start it from there). The installer opens that page. The first button press may
   ask to control "System Events": click OK. The first time you dictate, macOS asks to use
   the microphone: click Allow.

Updates arrive inside Quickpad: click "Check for updates" at the bottom of the panel.
Every update is signed, and Quickpad refuses one that isn't.

https://quickpad.praxentislabs.com.au
EOF
MAC_ZIP="$(make_zip mac)"

# ---- Linux (other distros; Mint/Ubuntu users are pointed at the .deb)
D="$WORK/linux/Quickpad"; mkdir -p "$D"
app_file quickpad.py "$D/quickpad.py" 755
for f in install-linux.sh install-mint.sh install-omarchy.sh; do app_file "$f" "$D/$f" 755; done
cat > "$D/READ-ME.txt" <<EOF
Quickpad $VERSION for Linux
===========================

On Linux Mint or Ubuntu, the .deb from the website is simpler: double-click it and
click Install. This zip is for other distributions, or if you prefer a script.

Unzip it, open a terminal in the Quickpad folder, and run one of these (each asks for
your password to install what Quickpad needs, such as python3-tk and xdotool or wtype):

   ./install-linux.sh      any distro (apt, pacman, dnf or zypper; X11 or Wayland)
   ./install-mint.sh       Linux Mint / Ubuntu
   ./install-omarchy.sh    Omarchy (Arch + Hyprland)

Add --autostart to start Quickpad when you log in, or --no-dictation to skip setting up
dictation (otherwise it takes a few minutes and needs the internet).

GNOME on Wayland blocks simulated typing: use the "GNOME on Xorg" session for Quickpad.

Updates arrive inside Quickpad: click "Check for updates" at the bottom of the panel.

https://quickpad.praxentislabs.com.au
EOF
LIN_ZIP="$(make_zip linux)"

echo "Built from $APP @ $REF ($COMMIT), Quickpad $VERSION"
for z in "$WIN_ZIP" "$MAC_ZIP" "$LIN_ZIP"; do
  printf '%-34s %8s bytes  sha256 %s\n' "$z" "$(stat -c %s "$OUT/$z")" "$(sha256sum "$OUT/$z" | cut -d' ' -f1)"
done
echo "Next: put these sizes and SHA-256s in the DOWNLOADS object in index.html, then run python3 tools/sync-downloads.py"
