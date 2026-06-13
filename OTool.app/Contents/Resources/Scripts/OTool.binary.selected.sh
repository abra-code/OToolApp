# Sidebar row selected: switch the inspected binary

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

# Hidden 3rd column carries the full path
dbg_trigger
path="$OMC_ACTIONUI_TABLE_10_COLUMN_3_VALUE"
dbg "col1=$OMC_ACTIONUI_TABLE_10_COLUMN_1_VALUE col3=$path"

if [ -z "$path" ]; then
    set_enabled "$REVEAL_BTN_ID" 0
    exit 0
fi

[ "$path" = "$(current_binary)" ] && exit 0

echo "$path" > "$(state_dir)/current.txt"
set_enabled "$REVEAL_BTN_ID" 1
update_binary_header

clear_loaded
reload_current_tab
