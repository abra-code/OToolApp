# Load command selected: show key/value fields (+ section table for segments)

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dir=$(state_dir)
idx="$OMC_ACTIONUI_TABLE_52_COLUMN_1_VALUE"
cmd="$OMC_ACTIONUI_TABLE_52_COLUMN_2_VALUE"
seg="$OMC_ACTIONUI_TABLE_52_COLUMN_4_VALUE"

if [ -z "$idx" ] || [ ! -f "$dir/fields-$idx.tsv" ]; then
    clear_table "$LC_FIELDS_TABLE_ID"
    set_visible "$LC_SECTIONS_GROUP_ID" 0
    set_value "$LC_DESC_TITLE_ID" ""
    set_value "$LC_DESC_TEXT_ID" "Select a load command to see what it does."
    /bin/rm -f "$dir/selected_lc.txt"
    exit 0
fi

# Detail-pane header: command name + plain-English description, and remember
# the selection so the Help (?) button can deep-link the reference to it.
set_value "$LC_DESC_TITLE_ID" "$cmd"
set_value "$LC_DESC_TEXT_ID" "$(lc_description "$cmd")"
printf '%s' "$cmd" > "$dir/selected_lc.txt"

feed_table "$LC_FIELDS_TABLE_ID" < "$dir/fields-$idx.tsv"

if [ -n "$seg" ] && [ -f "$dir/sections-$seg.tsv" ]; then
    feed_table "$LC_SECTIONS_TABLE_ID" < "$dir/sections-$seg.tsv"
    set_visible "$LC_SECTIONS_GROUP_ID" 1
else
    set_visible "$LC_SECTIONS_GROUP_ID" 0
fi
