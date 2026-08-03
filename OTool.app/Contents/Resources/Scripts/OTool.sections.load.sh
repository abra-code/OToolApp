# Sections tab: populate segment/section pickers from the cached otool -l parse

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

if tab_fresh sections; then dbg "fresh, skip"; exit 0; fi
dbg "loading: bin=$(current_binary) arch=$(current_arch) curtab=$(current_tab)"
wait_for_discovery || { dbg "discovery timeout"; exit 0; }
bin=$(current_binary)
[ -z "$bin" ] && exit 0
dir=$(state_dir)
# Captured now, re-checked before any UI write (see still_current in lib)
sig=$(tab_sig)

ensure_loadcmds_parsed

still_current "$sig" || { dbg "superseded, discarding"; exit 0; }

segs=$(/usr/bin/cut -f1 "$dir/segments.tsv" 2>/dev/null)
if [ -z "$segs" ]; then
    set_prop "$SEC_SEG_PICKER_ID" "options" '[]'
    set_prop "$SEC_SECT_PICKER_ID" "options" '[]'
    set_value "$SEC_EDITOR_ID" "No segments found."
    set_value "$SEC_STATUS_ID" ""
    # Drop the previous binary's dump, or Copy would still hand it over while the
    # pane says there is nothing to show.
    /bin/rm -f "$dir/sections_full.txt" "$dir/sections_out.txt"
    mark_loaded sections "$sig"
    exit 0
fi

# shellcheck disable=SC2086
set_prop "$SEC_SEG_PICKER_ID" "options" "$(json_array $segs)"
seg=$(echo "$segs" | /usr/bin/head -n 1)
case "$segs" in *__TEXT*) seg="__TEXT" ;; esac
# Pickers select by 1-based option index, not by name
set_value "$SEC_SEG_PICKER_ID" "$(list_index_of "$seg" "$(echo $segs)")"
echo "$seg" > "$dir/sections_seg.txt"

sect=$(populate_section_picker "$seg")
[ -n "$sect" ] && display_section "$seg" "$sect"

mark_loaded sections "$sig"
