# Disasm function-list filter (fires per keystroke; debounced ~200 ms).
# Each keystroke writes its token and waits; only the one still current after the
# wait re-feeds the table, so a burst of typing collapses to a single refresh.

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dir=$(state_dir)
tok=$$
printf '%s' "$tok" > "$dir/disasm_filter_gen.txt"
/bin/sleep 0.2
[ "$(/bin/cat "$dir/disasm_filter_gen.txt" 2>/dev/null)" = "$tok" ] || exit 0

refresh_disasm_funcs "$OMC_ACTIONUI_VIEW_61_VALUE"
