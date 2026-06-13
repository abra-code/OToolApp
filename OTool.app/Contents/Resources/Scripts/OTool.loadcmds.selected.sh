# Load command selected: show key/value fields (+ section table for segments)

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dir=$(state_dir)
idx="$OMC_ACTIONUI_TABLE_52_COLUMN_1_VALUE"
seg="$OMC_ACTIONUI_TABLE_52_COLUMN_4_VALUE"

if [ -z "$idx" ] || [ ! -f "$dir/fields-$idx.tsv" ]; then
    clear_table "$LC_FIELDS_TABLE_ID"
    set_visible "$LC_SECTIONS_GROUP_ID" 0
    exit 0
fi

feed_table "$LC_FIELDS_TABLE_ID" < "$dir/fields-$idx.tsv"

if [ -n "$seg" ] && [ -f "$dir/sections-$seg.tsv" ]; then
    feed_table "$LC_SECTIONS_TABLE_ID" < "$dir/sections-$seg.tsv"
    set_visible "$LC_SECTIONS_GROUP_ID" 1
else
    set_visible "$LC_SECTIONS_GROUP_ID" 0
fi
