# Help (?) button: open the Mach-O reference, deep-linked to the current context.
# The anchor is chosen from the active tab; on Load Commands it points at the
# specific command currently selected (remembered in selected_lc.txt).

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dir=$(state_dir)

case "$(current_tab)" in
    0) anchor="libraries" ;;
    1) anchor="header-flags" ;;
    2) anchor=$(/bin/cat "$dir/selected_lc.txt" 2>/dev/null)
       [ -z "$anchor" ] && anchor="load-commands"
       anchor="${anchor%_64}" ;;
    3) anchor="sections" ;;
    4) anchor="symbol-types" ;;
    *) anchor="load-commands" ;;
esac

# Hand the target anchor to the help window's init (it runs in a new window and
# has no access to this window's per-drop state). Kept in the per-user temp dir
# rather than /tmp, which is shared by every account on the machine, and swept
# in app.will.terminate.sh alongside the other markers.
printf '%s' "$anchor" > "${TMPDIR:-/tmp}/otool-help-target"

"$next_cmd" "$cmd_guid" "OTool.help.reference"
