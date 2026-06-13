# Content LoadableView loaded: fill in the header (name, path, icon, archs)

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

wait_for_discovery || { dbg "discovery timeout"; exit 0; }
dbg "updating header"
update_binary_header
