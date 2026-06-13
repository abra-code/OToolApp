# Filter the sidebar binary list (fires per keystroke)

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dir=$(state_dir)
[ -f "$dir/binaries.tsv" ] || exit 0

q="$OMC_ACTIONUI_VIEW_5_VALUE"
if [ -z "$q" ]; then
    feed_table "$SIDEBAR_TABLE_ID" < "$dir/binaries.tsv"
else
    /usr/bin/grep -i -F "$q" "$dir/binaries.tsv" | feed_table "$SIDEBAR_TABLE_ID"
fi
