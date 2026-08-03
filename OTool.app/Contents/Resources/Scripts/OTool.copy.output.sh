# Copy the current tab's primary output to the clipboard

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dir=$(state_dir)

# Sections and Disasm copy the full cached output rather than the shorter slice
# the editor renders: MAX_TEXT_LINES is only a rendering limit. Sections caches
# everything, so its copy is complete. Disasm's cache is itself bounded by
# MAX_SEARCH_LINES (draining the disassembly of a 339 MB binary would mean 1.2 GB),
# so on a binary large enough to hit that bound the copy stops there too - which
# is what the tab's status line reports.
case "$(current_tab)" in
    0) f="$dir/libs_raw.txt" ;;
    1) f="$dir/headers_raw.txt" ;;
    2) f="$dir/loadcmds_raw.txt" ;;
    3) f="$dir/sections_full.txt" ;;
    4) f="$dir/symbols_raw.txt" ;;
    5) f="$dir/disasm_full.txt" ;;
    *) exit 0 ;;
esac

if [ -s "$f" ]; then
    /usr/bin/pbcopy < "$f"
    "$notify_tool" --title "OTool" "Output copied to clipboard."
fi
