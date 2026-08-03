# Disasm: show the selected function's disassembly (scoped) in the editor, and
# remember the selection so an arch switch can re-disassemble the same function.

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dir=$(state_dir)
name="$OMC_ACTIONUI_TABLE_63_COLUMN_1_VALUE"   # Function column (visible)
addr="$OMC_ACTIONUI_TABLE_63_COLUMN_2_VALUE"   # Start address (hidden column)

if [ -z "$addr" ]; then
    : > "$dir/disasm_selected.txt"
    set_value "$DIS_EDITOR_ID" "Select a function to see its disassembly."
    exit 0
fi
[ -f "$dir/disasm_full.txt" ] || exit 0

# Extraction keys off the address, not the name: function names repeat (a normal
# framework has 167 duplicated names), so matching by name would always land on
# the first occurrence and make the other rows unreachable. The name is stored
# alongside it only to re-find the same function after an arch switch.
printf '%s\t%s' "$name" "$addr" > "$dir/disasm_selected.txt"
out=$(disasm_extract_func "$dir/disasm_full.txt" "$addr")
if [ -z "$out" ]; then
    set_value "$DIS_EDITOR_ID" "(no disassembly found for $name at $addr)"
else
    printf '%s\n' "$out" | set_value_stdin "$DIS_EDITOR_ID"
fi
