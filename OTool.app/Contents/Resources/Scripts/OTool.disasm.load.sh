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
# Captured now, re-checked before any UI write (see still_current in lib)
sig=$(tab_sig)

set_visible "$DIS_PROGRESS_ID" 1

# One line PAST the cap is fetched on purpose: whether that line exists is how we
# learn the listing was truncated, without having to read or store the whole
# output. Counting it exactly would mean draining everything - the full
# otool -tV of a 339 MB binary is 31.8M lines / 1.2 GB / ~9 s.
otool_run -tV "$bin" 2>&1 \
    | /usr/bin/head -n $((MAX_SEARCH_LINES + 1)) > "$dir/disasm_full.txt.$$"
truncated=""
if [ "$(/usr/bin/wc -l < "$dir/disasm_full.txt.$$" | /usr/bin/tr -d ' ')" -gt "$MAX_SEARCH_LINES" ]; then
    truncated=1
fi
disasm_build_funcs "$dir/disasm_full.txt.$$" > "$dir/disasm_funcs.tsv.$$"

# Nothing above touched the shared paths. A superseded loader therefore leaves no
# trace: it drops its private files and exits, instead of clobbering the cache of
# the binary the user actually has selected. (Two of these really can be in flight
# at once - OMC does not serialize handlers, and otool -tV on a large binary runs
# for seconds.)
if ! still_current "$sig"; then
    dbg "superseded, discarding"
    /bin/rm -f "$dir/disasm_full.txt.$$" "$dir/disasm_funcs.tsv.$$"
    exit 0
fi

/bin/mv "$dir/disasm_full.txt.$$" "$dir/disasm_full.txt"
/bin/mv "$dir/disasm_funcs.tsv.$$" "$dir/disasm_funcs.tsv"
if [ -n "$truncated" ]; then
    printf '1' > "$dir/disasm_truncated.txt"
else
    /bin/rm -f "$dir/disasm_truncated.txt"
fi

# Preserve the current filter text across reloads (e.g. an arch switch).
refresh_disasm_funcs "$OMC_ACTIONUI_VIEW_61_VALUE"

if [ ! -s "$dir/disasm_funcs.tsv" ]; then
    # No symbol labels (e.g. a stripped binary) - fall back to the plain listing.
    # Only the first MAX_TEXT_LINES are rendered; Copy still hands over the
    # complete (MAX_SEARCH_LINES) listing.
    /usr/bin/head -n "$MAX_TEXT_LINES" "$dir/disasm_full.txt" \
        | set_value_stdin "$DIS_EDITOR_ID"
else
    # Re-show the selected function disassembled for the current arch, so an arch
    # switch refreshes the detail in place; prompt if nothing valid is selected.
    # The remembered name is re-resolved to an address because the same function
    # sits at a different address in another slice.
    sel_name=$(/usr/bin/cut -f1 "$dir/disasm_selected.txt" 2>/dev/null)
    sel_addr=""
    [ -n "$sel_name" ] && sel_addr=$(disasm_addr_for_name "$sel_name")
    if [ -n "$sel_addr" ]; then
        printf '%s\t%s' "$sel_name" "$sel_addr" > "$dir/disasm_selected.txt"
        disasm_extract_func "$dir/disasm_full.txt" "$sel_addr" \
            | set_value_stdin "$DIS_EDITOR_ID"
    else
        set_value "$DIS_EDITOR_ID" "Select a function to see its disassembly."
    fi
fi

set_visible "$DIS_PROGRESS_ID" 0
mark_loaded disasm "$sig"
