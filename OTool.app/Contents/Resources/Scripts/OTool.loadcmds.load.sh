# Load Commands tab: list every load command with a one-line summary

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

if tab_fresh loadcmds; then dbg "fresh, skip"; exit 0; fi
dbg "loading: bin=$(current_binary) arch=$(current_arch) curtab=$(current_tab)"
wait_for_discovery || { dbg "discovery timeout"; exit 0; }
bin=$(current_binary)
[ -z "$bin" ] && exit 0
dir=$(state_dir)

ensure_loadcmds_parsed

set_value "$LC_FILTER_ID" ""
feed_table "$LC_TABLE_ID" < "$dir/cmds.tsv"
clear_table "$LC_FIELDS_TABLE_ID"
set_visible "$LC_SECTIONS_GROUP_ID" 0

mark_loaded loadcmds
