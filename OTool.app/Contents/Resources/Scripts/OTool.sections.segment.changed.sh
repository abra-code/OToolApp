# Segment picker changed: repopulate section picker, show first section

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dbg_trigger
dir=$(state_dir)

# The picker delivers the 1-based option index; resolve to the segment name
seglist=$(/usr/bin/cut -f1 "$dir/segments.tsv" 2>/dev/null | /usr/bin/tr '\n' ' ')
seg=""
for cand in "$OMC_ACTIONUI_TRIGGER_CONTEXT" "$OMC_ACTIONUI_VIEW_90_VALUE"; do
    seg=$(picker_resolve "$cand" "$seglist")
    [ -n "$seg" ] && break
done
dbg "resolved seg=$seg (view90=$OMC_ACTIONUI_VIEW_90_VALUE)"
[ -z "$seg" ] && exit 0

echo "$seg" > "$dir/sections_seg.txt"
sect=$(populate_section_picker "$seg")
[ -n "$sect" ] && display_section "$seg" "$sect"
