# Sidebar LoadableView loaded: populate the binary list table

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

wait_for_discovery || exit 0
dir=$(state_dir)

# Feed the rows, then visually select the first binary. It is already "current"
# (current.txt) and its details fill the header and every tab, but the highlight
# has to be set explicitly: set_value on a Table replaces its rows, it does not
# move the selection. select_row moves the highlight without touching the rows
# and fires no actionID — so this updates only the selection; the content was
# populated by content.load and the tab loaders, not by OTool.binary.selected.
feed_table "$SIDEBAR_TABLE_ID" < "$dir/binaries.tsv"

if [ -n "$(current_binary)" ]; then
    select_row "$SIDEBAR_TABLE_ID" 0
    set_enabled "$REVEAL_BTN_ID" 1
fi
