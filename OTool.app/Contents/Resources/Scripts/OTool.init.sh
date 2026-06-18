# OTool.init - INIT_SUBCOMMAND_ID of the main window; runs before the window
# appears. Discovers Mach-O binaries in the dropped/opened item and seeds the
# per-window state directory. Views inside LoadableViews don't exist yet —
# their viewDidLoad handlers (OTool.sidebar.load, OTool.content.load,
# OTool.*.load) populate the UI from this state.

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

# Hard prerequisite: the app reads Mach-O files via otool/nm/lipo. If the
# Command Line Tools aren't installed, seed an empty-but-ready state (so the
# window opens and no tab handler invokes a tool — which would pop Apple's own
# installer dialog) and tell the user how to install them, once per launch.
if ! tools_available; then
    dbg "command line tools missing; showing install guidance"
    dir=$(state_dir)
    echo "0"             > "$dir/curtab.txt"
    echo "$OMC_OBJ_PATH" > "$dir/obj.txt"
    : > "$dir/current.txt"
    echo ""              > "$dir/arch.txt"
    : > "$dir/binaries.tsv"          # readiness signal; empty = nothing to show
    [ -n "$OMC_OBJ_PATH" ] && set_window_title "$(/usr/bin/basename "$OMC_OBJ_PATH")"

    # mkdir is atomic, so only the first window of a multi-file drop alerts.
    warn_marker="${TMPDIR:-/tmp}/otool-clt-warned"
    if /bin/mkdir "$warn_marker" 2>/dev/null; then
        "$alert_tool" --level caution \
            --title "Command Line Tools required" \
            --ok "OK" \
"OTool reads Mach-O files using Apple's command-line tools (otool, nm, lipo), which don't appear to be installed.

To install them, open Terminal and run:

    xcode-select --install

then re-open your file in OTool."
    fi
    exit 0
fi

dbg "obj=$OMC_OBJ_PATH window=$window_uuid"
seed_window_state "$OMC_OBJ_PATH"
dbg "seeded $(/usr/bin/wc -l < "$(state_dir)/binaries.tsv" | /usr/bin/tr -d ' ') binaries, current=$(current_binary)"
