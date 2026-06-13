# Reveal the current binary in Finder

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

bin=$(current_binary)
[ -n "$bin" ] && /usr/bin/open -R "$bin"
