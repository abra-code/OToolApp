# OTool.main - main command body. Intentionally empty.
#
# The ACTIONUI_WINDOW handles the UI; OTool.init (INIT_SUBCOMMAND_ID) seeds
# the window state before the window appears, and LoadableView viewDidLoad
# handlers populate the views. For a non-blocking window this script's
# execution time is unpredictable, so it must not do any work — a main
# command body is only useful for blocking dialogs, to read the dialog's
# values before it is torn down.
exit 0
