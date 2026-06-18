# Disasm: show the selected function's disassembly (scoped) in the editor, and
# remember the selection so an arch switch can re-disassemble the same function.

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dir=$(state_dir)
name="$OMC_ACTIONUI_TABLE_63_COLUMN_1_VALUE"   # Function column (now the only column)

if [ -z "$name" ]; then
    : > "$dir/disasm_selected.txt"
    set_value "$DIS_EDITOR_ID" "Select a function to see its disassembly."
    exit 0
fi
[ -f "$dir/disasm_full.txt" ] || exit 0

printf '%s' "$name" > "$dir/disasm_selected.txt"
out=$(disasm_extract_func "$dir/disasm_full.txt" "$name")
[ -z "$out" ] && out="(no disassembly found for $name)"
set_value "$DIS_EDITOR_ID" "$out"
