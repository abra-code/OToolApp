# INIT_SUBCOMMAND for the Mach-O reference window: load the bundled HTML guide
# into the WebView (id 2), scrolled to the anchor chosen by OTool.help.sh.

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

WEBVIEW_ID=2
html="$OMC_APP_BUNDLE_PATH/Contents/Resources/Help/macho_reference.html"

anchor=$(/bin/cat /tmp/otool-help-target 2>/dev/null)
[ -z "$anchor" ] && anchor="load-commands"

# Build a file:// URL with the fragment. The install path can contain spaces;
# OTool bundles no Python, so percent-encode spaces dependency-free.
enc=$(printf '%s' "$html" | /usr/bin/sed 's/ /%20/g')
url="file://${enc}#${anchor}"

# In this init the window context (window_uuid) is the new help window's own UUID.
"$dialog_tool" "$window_uuid" "$WEBVIEW_ID" "$url"
