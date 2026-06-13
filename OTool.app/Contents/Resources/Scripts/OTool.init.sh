# OTool.init - INIT_SUBCOMMAND_ID of the main window; runs before the window
# appears. Discovers Mach-O binaries in the dropped/opened item and seeds the
# per-window state directory. Views inside LoadableViews don't exist yet —
# their viewDidLoad handlers (OTool.sidebar.load, OTool.content.load,
# OTool.*.load) populate the UI from this state.

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dbg "obj=$OMC_OBJ_PATH window=$window_uuid"
seed_window_state "$OMC_OBJ_PATH"
dbg "seeded $(/usr/bin/wc -l < "$(state_dir)/binaries.tsv" | /usr/bin/tr -d ' ') binaries, current=$(current_binary)"
