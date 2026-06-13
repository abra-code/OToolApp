# Section picker changed: dump the selected segment,section

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dbg_trigger
dir=$(state_dir)

# Current segment comes from state (the segment picker's exported value may
# be an index too); the section picker delivers the 1-based option index
seg=$(/bin/cat "$dir/sections_seg.txt" 2>/dev/null)
[ -z "$seg" ] && exit 0

sectlist=$(/usr/bin/cut -f1 "$dir/sections-$seg.tsv" 2>/dev/null | /usr/bin/tr '\n' ' ')
sect=""
for cand in "$OMC_ACTIONUI_TRIGGER_CONTEXT" "$OMC_ACTIONUI_VIEW_91_VALUE"; do
    sect=$(picker_resolve "$cand" "$sectlist")
    [ -n "$sect" ] && break
done
dbg "resolved seg=$seg sect=$sect (view91=$OMC_ACTIONUI_VIEW_91_VALUE)"
[ -z "$sect" ] && exit 0

display_section "$seg" "$sect"
