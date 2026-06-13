# Filter the load-command list (fires per keystroke)

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dir=$(state_dir)
[ -f "$dir/cmds.tsv" ] || exit 0

q="$OMC_ACTIONUI_VIEW_51_VALUE"
if [ -z "$q" ]; then
    feed_table "$LC_TABLE_ID" < "$dir/cmds.tsv"
else
    /usr/bin/grep -i -F "$q" "$dir/cmds.tsv" | feed_table "$LC_TABLE_ID"
fi
