# Symbols filter: text query (per keystroke) and kind picker share this handler

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

# Kind picker may deliver a 1-based index or a tag; order matches the JSON options
kind=$(picker_resolve "$OMC_ACTIONUI_VIEW_72_VALUE" "all defined undef indirect")
[ -z "$kind" ] && kind="all"

dbg "q=$OMC_ACTIONUI_VIEW_71_VALUE kind72=$OMC_ACTIONUI_VIEW_72_VALUE -> $kind"
refresh_symbols "$OMC_ACTIONUI_VIEW_71_VALUE" "$kind"
