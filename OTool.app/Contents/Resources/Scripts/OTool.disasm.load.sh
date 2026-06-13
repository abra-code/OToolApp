# Disassembly tab: otool -tV (lazy; only when the tab is actually visible)

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

if tab_fresh disasm; then dbg "fresh, skip"; exit 0; fi
dbg "loading: bin=$(current_binary) arch=$(current_arch) curtab=$(current_tab)"
# Skip the eager viewDidLoad at window open; OTool.tab.changed re-invokes us
[ "$(current_tab)" = "4" ] || { dbg "not current tab, skip"; exit 0; }
wait_for_discovery || { dbg "discovery timeout"; exit 0; }
bin=$(current_binary)
[ -z "$bin" ] && exit 0
dir=$(state_dir)

set_visible "$DIS_PROGRESS_ID" 1

otool_run -tV "$bin" 2>&1 | /usr/bin/head -n "$MAX_SEARCH_LINES" > "$dir/disasm_full.txt"
/usr/bin/head -n "$MAX_TEXT_LINES" "$dir/disasm_full.txt" > "$dir/disasm_raw.txt"

total=$(/usr/bin/wc -l < "$dir/disasm_full.txt" | /usr/bin/tr -d ' ')
if [ "$total" -gt "$MAX_TEXT_LINES" ]; then
    printf "\n… display truncated at %s of %s lines — use the symbol filter above …\n" \
        "$MAX_TEXT_LINES" "$total" >> "$dir/disasm_raw.txt"
fi

set_value "$DIS_EDITOR_ID" "$(/bin/cat "$dir/disasm_raw.txt")"
set_visible "$DIS_PROGRESS_ID" 0

mark_loaded disasm
