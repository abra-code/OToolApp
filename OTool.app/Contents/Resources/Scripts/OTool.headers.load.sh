# Headers tab: otool -hv (decoded Mach-O header) + lipo -detailed_info (fat slices)

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

if tab_fresh headers; then dbg "fresh, skip"; exit 0; fi
dbg "loading: bin=$(current_binary) arch=$(current_arch) curtab=$(current_tab)"
wait_for_discovery || { dbg "discovery timeout"; exit 0; }
bin=$(current_binary)
[ -z "$bin" ] && exit 0
dir=$(state_dir)

otool_run -hv "$bin" > "$dir/headers_raw.txt" 2>&1

# Data row follows the "magic cputype ..." column header line:
# MH_MAGIC_64  ARM64E  ALL  0x00  EXECUTE  21  3368  NOUNDEFS DYLDLINK TWOLEVEL PIE
/usr/bin/awk '
    /^ *magic +cputype/ { hdr = 1; next }
    hdr {
        printf "Magic\t%s\n", $1
        printf "CPU Type\t%s\n", $2
        printf "CPU Subtype\t%s\n", $3
        printf "Capabilities\t%s\n", $4
        printf "File Type\t%s\n", $5
        printf "Load Commands\t%s\n", $6
        printf "Size of Load Cmds\t%s bytes\n", $7
        flags = ""
        for (i = 8; i <= NF; i++) flags = flags (flags == "" ? "" : " ") $i
        printf "Flags\t%s\n", flags
        exit
    }
' "$dir/headers_raw.txt" | feed_table "$HDR_TABLE_ID"

# Fat slices
archs=$(detect_architectures "$bin")
count=$(echo "$archs" | /usr/bin/wc -w | /usr/bin/tr -d ' ')
if [ "$count" -gt 1 ]; then
    "$LIPO" -detailed_info "$bin" 2>/dev/null | /usr/bin/awk '
        function flush() {
            if (a != "") printf "%s\t%s\t%s\t%s\n", a, o, s, al
            a = ""; o = ""; s = ""; al = ""
        }
        /^architecture / { flush(); a = $2 }
        /^ *offset /     { o = $2 }
        /^ *size /       { s = $2 }
        /^ *align /      { al = $2 " " $3 }
        END { flush() }
    ' | feed_table "$FAT_TABLE_ID"
    set_visible "$FAT_GROUP_ID" 1
else
    set_visible "$FAT_GROUP_ID" 0
fi

mark_loaded headers
