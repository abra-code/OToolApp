# App quitting: sweep any leftover per-window state directories

/bin/rm -rf "${TMPDIR:-/tmp}"/otool-state-*
/bin/rm -rf "${TMPDIR:-/tmp}"/otool-clt-warned
