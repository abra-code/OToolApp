# Symbols filter: text query (per keystroke) and kind picker share this handler

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

# Kind picker may deliver a 1-based index or a tag; order matches the JSON options
kind=$(picker_resolve "$OMC_ACTIONUI_VIEW_72_VALUE" "all defined exported undef indirect")
[ -z "$kind" ] && kind="all"

# Debounce per-keystroke typing in the filter field (~200 ms): each keystroke
# writes its own token and waits; only the one still current after the wait does
# the work, so a burst of keystrokes collapses to a single refresh. The kind
# picker shares this handler but applies immediately (no debounce).
if [ "$OMC_ACTIONUI_TRIGGER_VIEW_ID" = "$SYM_FILTER_ID" ]; then
    dir=$(state_dir)
    tok=$$
    printf '%s' "$tok" > "$dir/sym_filter_gen.txt"
    /bin/sleep 0.2
    [ "$(/bin/cat "$dir/sym_filter_gen.txt" 2>/dev/null)" = "$tok" ] || exit 0
fi

dbg "q=$OMC_ACTIONUI_VIEW_71_VALUE kind=$kind"
refresh_symbols "$OMC_ACTIONUI_VIEW_71_VALUE" "$kind"
