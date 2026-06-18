# Disassembly tab (master/detail): run otool -tV once, build the function list.
# The scoped disassembly is shown by OTool.disasm.selected when a function is
# picked; OTool.disasm.filter narrows the list. Lazy: only when the tab is shown.

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

if tab_fresh disasm; then dbg "fresh, skip"; exit 0; fi
dbg "loading: bin=$(current_binary) arch=$(current_arch) curtab=$(current_tab)"
# Skip the eager viewDidLoad at window open; OTool.tab.changed re-invokes us
[ "$(current_tab)" = "5" ] || { dbg "not current tab, skip"; exit 0; }
wait_for_discovery || { dbg "discovery timeout"; exit 0; }
bin=$(current_binary)
[ -z "$bin" ] && exit 0
dir=$(state_dir)

set_visible "$DIS_PROGRESS_ID" 1

otool_run -tV "$bin" 2>&1 | /usr/bin/head -n "$MAX_SEARCH_LINES" > "$dir/disasm_full.txt"
disasm_build_funcs "$dir/disasm_full.txt" > "$dir/disasm_funcs.tsv"

# Full (capped) listing kept for the Copy button.
/usr/bin/head -n "$MAX_TEXT_LINES" "$dir/disasm_full.txt" > "$dir/disasm_raw.txt"

# Preserve the current filter text across reloads (e.g. an arch switch).
refresh_disasm_funcs "$OMC_ACTIONUI_VIEW_61_VALUE"

if [ ! -s "$dir/disasm_funcs.tsv" ]; then
    # No symbol labels (e.g. stripped) — fall back to the full __text listing.
    set_value "$DIS_EDITOR_ID" "$(/bin/cat "$dir/disasm_raw.txt")"
else
    # Re-show the selected function disassembled for the current arch, so an arch
    # switch refreshes the detail in place; prompt if nothing valid is selected.
    sel=$(/bin/cat "$dir/disasm_selected.txt" 2>/dev/null)
    if [ -n "$sel" ] && /usr/bin/grep -Fxq "$sel" "$dir/disasm_funcs.tsv"; then
        set_value "$DIS_EDITOR_ID" "$(disasm_extract_func "$dir/disasm_full.txt" "$sel")"
    else
        set_value "$DIS_EDITOR_ID" "Select a function to see its disassembly."
    fi
fi

set_visible "$DIS_PROGRESS_ID" 0
mark_loaded disasm
