# Copy the current tab's primary output to the clipboard

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dir=$(state_dir)

case "$(current_tab)" in
    0) f="$dir/libs_raw.txt" ;;
    1) f="$dir/headers_raw.txt" ;;
    2) f="$dir/loadcmds_raw.txt" ;;
    3) f="$dir/sections_out.txt" ;;
    4) f="$dir/disasm_raw.txt" ;;
    5) f="$dir/symbols_raw.txt" ;;
    *) exit 0 ;;
esac

if [ -s "$f" ]; then
    /usr/bin/pbcopy < "$f"
    "$notify_tool" --title "OTool" "Output copied to clipboard."
fi
