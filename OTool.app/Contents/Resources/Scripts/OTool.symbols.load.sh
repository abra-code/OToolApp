# Symbols tab: nm (symbol table) + otool -Iv (indirect symbols), lazy

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

if tab_fresh symbols; then dbg "fresh, skip"; exit 0; fi
dbg "loading: bin=$(current_binary) arch=$(current_arch) curtab=$(current_tab)"
# Skip the eager viewDidLoad at window open; OTool.tab.changed re-invokes us
[ "$(current_tab)" = "4" ] || { dbg "not current tab, skip"; exit 0; }
wait_for_discovery || { dbg "discovery timeout"; exit 0; }
bin=$(current_binary)
[ -z "$bin" ] && exit 0
dir=$(state_dir)

# Reset the demangle line for the newly loaded binary/arch.
set_value "$SYM_LANG_ID" ""
set_value "$SYM_DEMANGLE_ID" "Select a symbol to see it demangled"

arch=$(safe_arch)
if [ -n "$arch" ]; then
    "$NM" -arch "$arch" "$bin" 2>/dev/null > "$dir/symbols_raw.txt"
else
    "$NM" "$bin" 2>/dev/null > "$dir/symbols_raw.txt"
fi

# nm lines: "0000000100003f20 T _main"  or  "                 U _printf"
/usr/bin/awk '
    NF >= 3 { addr = $1; type = $2; name = $3;
              for (i = 4; i <= NF; i++) name = name " " $i
              printf "%s\t%s\t%s\n", addr, type, name; next }
    NF == 2 { printf "\t%s\t%s\n", $1, $2 }
' "$dir/symbols_raw.txt" > "$dir/symbols.tsv"

# otool -Iv lines: "0x0000000100003f7a    10 _printf"
otool_run -Iv "$bin" 2>/dev/null | /usr/bin/awk '
    /^0x/ { name = $3
            for (i = 4; i <= NF; i++) name = name " " $i
            printf "%s\tIND\t%s\n", $1, name }
' > "$dir/indirect.tsv"

kind=$(picker_resolve "$OMC_ACTIONUI_VIEW_72_VALUE" "all defined exported undef indirect")
[ -z "$kind" ] && kind="all"
refresh_symbols "$OMC_ACTIONUI_VIEW_71_VALUE" "$kind"

mark_loaded symbols
