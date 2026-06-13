# Sidebar LoadableView loaded: populate the binary list table

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

wait_for_discovery || exit 0
dir=$(state_dir)

# Note: do NOT set_value on a Table — that replaces its rows, not the
# selection. The first binary is already "current" via current.txt; tabs
# load it without a visual selection.
feed_table "$SIDEBAR_TABLE_ID" < "$dir/binaries.tsv"

[ -n "$(current_binary)" ] && set_enabled "$REVEAL_BTN_ID" 1
