# Window closed: remove this window's state directory

if [ -n "$OMC_ACTIONUI_WINDOW_UUID" ]; then
    /bin/rm -rf "${TMPDIR:-/tmp}/otool-state-${OMC_ACTIONUI_WINDOW_UUID}"
fi
