# Tab switched: remember it and (re)load it if stale.
# Fired by both the per-Tab actionIDs (trigger view id 401-407) and the
# TabView-level actionID (trigger view id 20, tab index as context).

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dbg_trigger
idx=""

# Per-Tab event: derive the index from the Tab element's id
case "$OMC_ACTIONUI_TRIGGER_VIEW_ID" in
    40[1-7]) idx=$((OMC_ACTIONUI_TRIGGER_VIEW_ID - 401)) ;;
esac

# TabView event: index arrives as trigger context / part id
if [ -z "$idx" ]; then
    for cand in "$OMC_ACTIONUI_TRIGGER_CONTEXT" "$OMC_ACTIONUI_TRIGGER_VIEW_PART_ID"; do
        case "$cand" in
            ''|*[!0-9]*) ;;
            *) idx="$cand"; break ;;
        esac
    done
fi
dbg "derived idx=$idx curtab=$(current_tab)"
[ -z "$idx" ] && exit 0

# Both event sources fire for the same switch — only act on a real change
[ "$idx" = "$(current_tab)" ] && exit 0

echo "$idx" > "$(state_dir)/curtab.txt"

loader=$(tab_loader_for_index "$idx")
dbg "chaining loader=$loader"
[ -n "$loader" ] && "$next_cmd" "$cmd_guid" "$loader"
