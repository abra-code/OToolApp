# App quitting: sweep any leftover per-window state directories

/bin/rm -rf "${TMPDIR:-/tmp}"/otool-state-*
/bin/rm -rf "${TMPDIR:-/tmp}"/otool-clt-warned
/bin/rm -f  "${TMPDIR:-/tmp}"/otool-help-target
