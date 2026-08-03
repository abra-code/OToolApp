# INIT_SUBCOMMAND for the Mach-O reference window: load the bundled HTML guide
# into the WebView (id 2), scrolled to the anchor chosen by OTool.help.sh.

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

WEBVIEW_ID=2
html="$OMC_APP_BUNDLE_PATH/Contents/Resources/Help/macho_reference.html"

anchor=$(/bin/cat "${TMPDIR:-/tmp}/otool-help-target" 2>/dev/null)
[ -z "$anchor" ] && anchor="load-commands"

# Build a file:// URL with the fragment. The install path is wherever the user
# put the app, so it can contain characters that change how the URL parses -
# '#' would swallow the rest of the path as a fragment, '?' as a query - not
# just spaces. OTool bundles no Python, so percent-encode by hand; '%' has to go
# first or it would re-encode the escapes introduced after it.
enc=$(printf '%s' "$html" | /usr/bin/sed \
    -e 's/%/%25/g' \
    -e 's/ /%20/g' \
    -e 's/#/%23/g' \
    -e 's/?/%3F/g' \
    -e 's/\[/%5B/g' \
    -e 's/\]/%5D/g')
url="file://${enc}#${anchor}"

# In this init the window context (window_uuid) is the new help window's own UUID.
"$dialog_tool" "$window_uuid" "$WEBVIEW_ID" "$url"
