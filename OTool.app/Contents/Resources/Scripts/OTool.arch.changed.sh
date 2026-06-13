# Architecture segmented control changed: invalidate and reload visible tab

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

dbg_trigger
dbg "view210=$OMC_ACTIONUI_VIEW_210_VALUE stored=$(current_arch) curtab=$(current_tab)"

# Picker options as set by update_binary_header, in display order
archs=$(/bin/cat "$(state_dir)/archs.txt" 2>/dev/null)
[ -z "$archs" ] && archs=$(detect_architectures "$(current_binary)")

# The picker delivers the 1-based option index (a name is also accepted);
# resolve against the option list — this also rejects bogus values from
# programmatic options/value updates.
arch=""
for cand in "$OMC_ACTIONUI_TRIGGER_CONTEXT" "$OMC_ACTIONUI_VIEW_210_VALUE"; do
    arch=$(picker_resolve "$cand" "$archs")
    [ -n "$arch" ] && break
done
dbg "resolved arch=$arch (archs=$archs)"
[ -z "$arch" ] && exit 0

[ "$arch" = "$(current_arch)" ] && exit 0

echo "$arch" > "$(state_dir)/arch.txt"
clear_loaded
dbg "arch -> $arch, reloading tab $(current_tab)"
reload_current_tab
