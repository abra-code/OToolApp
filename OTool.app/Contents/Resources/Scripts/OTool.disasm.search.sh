# Disasm symbol search (fires on Return): show only function blocks whose
# label matches; empty query restores the full (capped) listing

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dir=$(state_dir)
[ -f "$dir/disasm_full.txt" ] || exit 0

q="$OMC_ACTIONUI_VIEW_61_VALUE"
if [ -z "$q" ]; then
    set_value "$DIS_EDITOR_ID" "$(/bin/cat "$dir/disasm_raw.txt")"
    exit 0
fi

# Labels are non-indented lines ending with ':'; print from a matching label
# until the next label
out=$(/usr/bin/awk -v q="$(echo "$q" | /usr/bin/tr 'A-Z' 'a-z')" '
    /^[^ \t].*:[ \t]*$/ { show = (index(tolower($0), q) > 0) }
    show { print }
' "$dir/disasm_full.txt" | /usr/bin/head -n "$MAX_TEXT_LINES")

if [ -n "$out" ]; then
    set_value "$DIS_EDITOR_ID" "$out"
else
    set_value "$DIS_EDITOR_ID" "No symbol matching \"$q\""
fi
