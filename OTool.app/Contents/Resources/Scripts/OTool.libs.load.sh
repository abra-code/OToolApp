# Libraries tab: otool -L (+ -D install name), with path resolution markers

source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

if tab_fresh libs; then dbg "fresh, skip"; exit 0; fi
dbg "loading: bin=$(current_binary) arch=$(current_arch) curtab=$(current_tab)"
wait_for_discovery || { dbg "discovery timeout"; exit 0; }
bin=$(current_binary)
[ -z "$bin" ] && exit 0
dir=$(state_dir)
bindir=$(/usr/bin/dirname "$bin")

# rpaths.txt is needed for @rpath resolution
ensure_loadcmds_parsed

otool_run -L "$bin" > "$dir/libs_raw.txt" 2>&1

# Install name (dylibs only): second line of otool -D
install=$(otool_run -D "$bin" 2>/dev/null | /usr/bin/sed -n '2p')
if [ -n "$install" ]; then
    set_value "$LIBS_INSTALL_NAME_ID" "Install name: $install"
else
    set_value "$LIBS_INSTALL_NAME_ID" ""
fi

# Lines look like:  \t/path (compatibility version 1.0.0, current version 2.3.0)
/usr/bin/tail -n +2 "$dir/libs_raw.txt" | /usr/bin/sed -E \
    -e 's/^[[:space:]]+//' \
    -e 's/ \(compatibility version ([^,]+), current version ([^)]+)\)$/\t\1\t\2/' \
    | while IFS=$(printf '\t') read -r path compat current; do
    [ -z "$path" ] && continue
    marker=$(lib_status_marker "$path" "$bindir")
    printf "%s\t%s\t%s\t%s\n" "$marker" "$path" "$compat" "$current"
done | feed_table "$LIBS_TABLE_ID"

mark_loaded libs
