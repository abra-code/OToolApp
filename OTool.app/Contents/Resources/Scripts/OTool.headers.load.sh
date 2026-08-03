# Headers tab: otool -hv (decoded Mach-O header) + lipo -detailed_info (fat slices)

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

if tab_fresh headers; then dbg "fresh, skip"; exit 0; fi
dbg "loading: bin=$(current_binary) arch=$(current_arch) curtab=$(current_tab)"
wait_for_discovery || { dbg "discovery timeout"; exit 0; }
bin=$(current_binary)
[ -z "$bin" ] && exit 0
dir=$(state_dir)
# Captured now, re-checked before any UI write (see still_current in lib)
sig=$(tab_sig)

# Private name until the guard passes: headers_raw.txt is what Copy hands over, so
# a superseded run writing it directly could leave the previous binary's header
# (or a byte-interleaved mix of two) behind the correct on-screen table.
otool_run -hv "$bin" > "$dir/headers_raw.txt.$$" 2>&1
archs=$(detect_architectures "$bin")
count=$(echo "$archs" | /usr/bin/wc -w | /usr/bin/tr -d ' ')

if ! still_current "$sig"; then
    dbg "superseded, discarding"
    /bin/rm -f "$dir/headers_raw.txt.$$"
    exit 0
fi
/bin/mv "$dir/headers_raw.txt.$$" "$dir/headers_raw.txt"

# Data row follows the "magic cputype ..." column header line:
# MH_MAGIC_64  ARM64E  ALL  0x00  EXECUTE  21  3368  NOUNDEFS DYLDLINK TWOLEVEL PIE
/usr/bin/awk '
    /^ *magic +cputype/ { hdr = 1; next }
    hdr {
        subtype = $3
        # otool -hv reports arm64e as cputype ARM64 + cpusubtype E, which alone
        # reads as a meaningless single letter. Name it.
        if ($2 == "ARM64" && $3 == "E") subtype = "E   (arm64e)"
        printf "Magic\t%s\n", $1
        printf "CPU Type\t%s\n", $2
        printf "CPU Subtype\t%s\n", subtype
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

mark_loaded headers "$sig"
