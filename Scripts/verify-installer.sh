#!/bin/zsh

set -euo pipefail

installer=${1:?Usage: verify-installer.sh INSTALLER.dmg}
if [[ ! -f "$installer" ]]; then
    print -u2 "Installer not found: $installer"
    exit 1
fi

hdiutil verify "$installer" >/dev/null

mount_directory=$(mktemp -d /tmp/linkrouter-installer.XXXXXX)
mounted=false
cleanup() {
    if [[ "$mounted" == true ]]; then
        hdiutil detach "$mount_directory" -quiet || true
    fi
    rmdir "$mount_directory" 2>/dev/null || true
}
trap cleanup EXIT

hdiutil attach "$installer" -readonly -nobrowse -mountpoint "$mount_directory" >/dev/null
mounted=true

app="$mount_directory/LinkRouter.app"
info="$app/Contents/Info.plist"
icon="$app/Contents/Resources/AppIcon.icns"

[[ -d "$app" ]] || { print -u2 "LinkRouter.app is missing from the installer"; exit 1; }
[[ -x "$app/Contents/MacOS/LinkRouter" ]] || { print -u2 "LinkRouter executable is missing"; exit 1; }
[[ -L "$mount_directory/Applications" ]] || { print -u2 "Applications shortcut is missing"; exit 1; }
[[ "$(readlink "$mount_directory/Applications")" == "/Applications" ]] || {
    print -u2 "Applications shortcut has the wrong destination"
    exit 1
}
[[ "$(plutil -extract CFBundleIconFile raw "$info")" == "AppIcon.icns" ]] || {
    print -u2 "The app bundle does not declare AppIcon.icns"
    exit 1
}
[[ "$(plutil -extract LSUIElement raw "$info")" == "true" ]] || {
    print -u2 "The app bundle is not configured as a menu-bar agent"
    exit 1
}
[[ "$(plutil -extract CFBundleURLTypes.0.CFBundleURLSchemes.0 raw "$info")" == "http" ]] || {
    print -u2 "The app bundle does not declare the http URL scheme"
    exit 1
}
[[ "$(plutil -extract CFBundleURLTypes.0.CFBundleURLSchemes.1 raw "$info")" == "https" ]] || {
    print -u2 "The app bundle does not declare the https URL scheme"
    exit 1
}
[[ "$(plutil -extract CFBundleURLTypes.1.CFBundleURLSchemes.0 raw "$info")" == "file" ]] || {
    print -u2 "The app bundle does not declare the file URL scheme"
    exit 1
}
[[ "$(plutil -extract CFBundleDocumentTypes.0.LSItemContentTypes.0 raw "$info")" == "public.html" ]] || {
    print -u2 "The app bundle does not declare HTML document support"
    exit 1
}
[[ -f "$icon" ]] || { print -u2 "AppIcon.icns is missing from the app bundle"; exit 1; }
codesign --verify --deep --strict "$app"

print "PASS: verified $installer"
