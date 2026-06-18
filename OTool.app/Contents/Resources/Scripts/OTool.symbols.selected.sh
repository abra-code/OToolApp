# Symbols tab: on selection change, demangle the selected symbol into the
# read-only, selectable Text under the table. C++ / Swift go through c++filt /
# swift-demangle (resolved at run time); plain C just loses the linker's leading
# underscore. This fires on every selection, so a missing tool is reported
# inline (no notification).

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

sym="$OMC_ACTIONUI_TABLE_70_COLUMN_3_VALUE"   # column 3 = Symbol (1-based)

if [ -z "$sym" ]; then
    set_value "$SYM_LANG_ID" ""
    set_value "$SYM_DEMANGLE_ID" "Select a symbol to see it demangled"
    exit 0
fi

lang=$(symbol_language "$sym")
out=""

case "$lang" in
    "c++")
        tool=$(cxxfilt_tool)
        if [ -n "$tool" ]; then
            out=$(printf '%s' "$sym" | "$tool" 2>/dev/null)
        else
            out="c++filt not installed — run: xcode-select --install"
        fi ;;
    swift)
        tool=$(swift_demangle_tool)
        if [ -n "$tool" ]; then
            out=$(printf '%s' "$sym" | "$tool" -compact 2>/dev/null)
        else
            out="swift-demangle not installed — run: xcode-select --install"
        fi ;;
    objc)
        out=$(objc_demangle "$sym") ;;
    *)
        out="${sym#_}" ;;
esac

[ -z "$out" ] && out="$sym"
if [ "$lang" != "c" ] && [ "$out" = "$sym" ]; then
    out="(could not demangle)"
fi

set_value "$SYM_LANG_ID" "$(symbol_language_label "$lang")"
set_value "$SYM_DEMANGLE_ID" "$out"
