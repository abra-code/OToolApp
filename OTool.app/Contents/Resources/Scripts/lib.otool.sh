# lib.otool.sh - shared library for the OTool applet
#
# Sourced by every handler script:
#   source "${OMC_APP_BUNDLE_PATH}/Contents/Resources/Scripts/lib.otool.sh"

[ -n "$__LIB_OTOOL_SH" ] && return 0
__LIB_OTOOL_SH=1

# ──────────────────────────────────────────────────────────────
# Tools and window context
# ──────────────────────────────────────────────────────────────

dialog_tool="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"
next_cmd="$OMC_OMC_SUPPORT_PATH/omc_next_command"
notify_tool="$OMC_OMC_SUPPORT_PATH/notify"
alert_tool="$OMC_OMC_SUPPORT_PATH/alert"
window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
cmd_guid="$OMC_CURRENT_COMMAND_GUID"

OTOOL=/usr/bin/otool
LIPO=/usr/bin/lipo
NM=/usr/bin/nm
CXXFILT=/usr/bin/c++filt
XCRUN=/usr/bin/xcrun

# ──────────────────────────────────────────────────────────────
# Control IDs (match ids in Base.lproj/*.json)
# ──────────────────────────────────────────────────────────────

SIDEBAR_FILTER_ID=5
SIDEBAR_TABLE_ID=10
REVEAL_BTN_ID=17

TAB_VIEW_ID=20
HEADER_ICON_ID=201
HEADER_NAME_ID=202
HEADER_PATH_ID=203
ARCH_PICKER_ID=210
COPY_BTN_ID=221

LIBS_TABLE_ID=30
LIBS_INSTALL_NAME_ID=31

HDR_TABLE_ID=40
FAT_GROUP_ID=41
FAT_TABLE_ID=42

LC_FILTER_ID=51
LC_TABLE_ID=52
LC_FIELDS_TABLE_ID=54
LC_SECTIONS_GROUP_ID=55
LC_SECTIONS_TABLE_ID=56
LC_DESC_TITLE_ID=57
LC_DESC_TEXT_ID=58
LC_HELP_BTN_ID=59

DIS_EDITOR_ID=60
DIS_FILTER_ID=61
DIS_PROGRESS_ID=62
DIS_FUNCS_TABLE_ID=63
DIS_STATUS_ID=64

SYM_TABLE_ID=70
SYM_FILTER_ID=71
SYM_KIND_ID=72
SYM_STATUS_ID=73
SYM_HELP_BTN_ID=74
SYM_DEMANGLE_ID=76
SYM_LANG_ID=77

SEC_SEG_PICKER_ID=90
SEC_SECT_PICKER_ID=91
SEC_EDITOR_ID=92
SEC_STATUS_ID=93
SEC_PROGRESS_ID=94

# Output size limits
MAX_TEXT_LINES=20000
MAX_SEARCH_LINES=200000
MAX_TABLE_ROWS=50000

# ──────────────────────────────────────────────────────────────
# Debug logging — enabled by `touch /tmp/otool-debug-on`,
# written to /tmp/otool-debug.log
# ──────────────────────────────────────────────────────────────

OTOOL_DEBUG_FLAG=/tmp/otool-debug-on
OTOOL_DEBUG_LOG=/tmp/otool-debug.log

dbg() {
    [ -f "$OTOOL_DEBUG_FLAG" ] || return 0
    echo "$(/bin/date +%H:%M:%S) [$(/usr/bin/basename "$0" .sh)] $*" >> "$OTOOL_DEBUG_LOG"
}

# Log the ActionUI trigger environment of the current handler
dbg_trigger() {
    [ -f "$OTOOL_DEBUG_FLAG" ] || return 0
    dbg "trigger view=$OMC_ACTIONUI_TRIGGER_VIEW_ID part=$OMC_ACTIONUI_TRIGGER_VIEW_PART_ID ctx=$OMC_ACTIONUI_TRIGGER_CONTEXT"
}

# ──────────────────────────────────────────────────────────────
# Per-window state directory
# ──────────────────────────────────────────────────────────────

state_dir() {
    local dir="${TMPDIR:-/tmp}/otool-state-${window_uuid}"
    /bin/mkdir -p "$dir"
    echo "$dir"
}

current_binary() { /bin/cat "$(state_dir)/current.txt" 2>/dev/null; }
current_arch()   { /bin/cat "$(state_dir)/arch.txt" 2>/dev/null; }

# True (0) when Apple's command-line tools (otool/nm/lipo) are installed and
# usable. The whole app is built on them, but /usr/bin/otool etc. are only
# xcode-select stubs — without the Command Line Tools (or Xcode) they fail and
# pop the system "install developer tools" dialog. This check stays GUI-safe by
# using only `xcode-select -p` + a filesystem test: it never invokes the bare
# stub, so it cannot itself trigger that dialog when nothing is installed.
tools_available() {
    local dd otool
    dd=$(/usr/bin/xcode-select -p 2>/dev/null) || return 1
    [ -n "$dd" ] && [ -d "$dd" ] || return 1
    # A developer dir is configured, so resolving a tool won't prompt to install.
    otool=$(/usr/bin/xcrun -f otool 2>/dev/null) || return 1
    [ -n "$otool" ] && [ -x "$otool" ]
}
current_tab() {
    local t
    t=$(/bin/cat "$(state_dir)/curtab.txt" 2>/dev/null)
    echo "${t:-0}"
}

# Block until OTool.main.sh has finished discovery (max ~10 s)
wait_for_discovery() {
    local i=0
    while [ $i -lt 100 ]; do
        [ -f "$(state_dir)/binaries.tsv" ] && return 0
        /bin/sleep 0.1
        i=$((i + 1))
    done
    return 1
}

# ──────────────────────────────────────────────────────────────
# UI helpers
# ──────────────────────────────────────────────────────────────

set_value()   { "$dialog_tool" "$window_uuid" "$1" "$2"; }
set_prop()    { "$dialog_tool" "$window_uuid" "$1" omc_set_property "$2" "$3"; }
feed_table()  { "$dialog_tool" "$window_uuid" "$1" omc_table_set_rows_from_stdin; }
clear_table() { printf "" | feed_table "$1"; }
# Visually select a Table/List row by 0-based index. Fires no actionID, so the
# selection-change handler is NOT invoked — the caller must update any detail
# pane itself. Setting a Table's value would replace its rows, not move the
# selection, which is why this dedicated verb exists.
select_row()  { "$dialog_tool" "$window_uuid" "$1" omc_select_row "$2"; }
set_window_title() { "$dialog_tool" "$window_uuid" omc_window "$1"; }

set_enabled() {
    if [ "$2" = "1" ] || [ "$2" = "true" ]; then
        "$dialog_tool" "$window_uuid" "$1" omc_enable
    else
        "$dialog_tool" "$window_uuid" "$1" omc_disable
    fi
}

set_visible() {
    if [ "$2" = "1" ] || [ "$2" = "true" ]; then
        "$dialog_tool" "$window_uuid" "$1" omc_show
    else
        "$dialog_tool" "$window_uuid" "$1" omc_hide
    fi
}

# True if $1 appears as a whole word in the space-separated list $2
word_in_list() {
    case " $2 " in
        *" $1 "*) return 0 ;;
    esac
    return 1
}

# 1-based index of word $1 in the space-separated list $2; empty if absent
list_index_of() {
    local i=1 w
    for w in $2; do
        if [ "$w" = "$1" ]; then
            echo "$i"
            return 0
        fi
        i=$((i + 1))
    done
    echo ""
}

# Word at 1-based index $1 in the space-separated list $2
list_word_at() {
    # shellcheck disable=SC2086
    echo $2 | /usr/bin/awk -v n="$1" '{ print $n }'
}

# Resolve a Picker value to an option name. ActionUI pickers deliver the
# 1-based option index (observed: segmented picker sends "1"/"2"), but a
# name/tag may also come through — accept both. $1 = raw value,
# $2 = space-separated option names, in the same order as the picker options.
picker_resolve() {
    local val="$1" list="$2"
    if [ -n "$val" ] && word_in_list "$val" "$list"; then
        echo "$val"
        return 0
    fi
    case "$val" in
        ''|*[!0-9]*) echo "" ;;
        *) list_word_at "$val" "$list" ;;
    esac
}

# Build a JSON string array from arguments: json_array a b -> ["a","b"]
json_array() {
    local out="[" first=1 item
    for item in "$@"; do
        [ $first -eq 1 ] || out="$out,"
        out="$out\"$item\""
        first=0
    done
    echo "$out]"
}

# ──────────────────────────────────────────────────────────────
# Binary inspection helpers
# ──────────────────────────────────────────────────────────────

# True if file starts with a Mach-O or fat magic
is_macho() {
    local m
    m=$(/usr/bin/od -An -tx1 -N4 "$1" 2>/dev/null | /usr/bin/tr -d ' \n')
    case "$m" in
        feedface|cefaedfe|feedfacf|cffaedfe|cafebabe|bebafeca|cafebabf|bfbafeca) return 0 ;;
    esac
    return 1
}

# Echo lowercase Mach-O file type: execute / dylib / bundle / object / ...
classify_binary() {
    "$OTOOL" -hv "$1" 2>/dev/null | /usr/bin/awk '
        /^(MH_MAGIC|MH_CIGAM| *0x)/ { print tolower($5); exit }'
}

# Echo space-separated architectures of a binary
detect_architectures() {
    "$LIPO" -archs "$1" 2>/dev/null
}

# SF Symbol name for a binary type badge
icon_for_type() {
    case "$1" in
        execute) echo "apple.terminal.fill" ;;
        dylib)   echo "shippingbox.fill" ;;
        bundle)  echo "puzzlepiece.extension.fill" ;;
        *)       echo "doc.fill" ;;
    esac
}

# Current arch, but only when it is a single sane token — a corrupt
# arch.txt must never turn every tab into otool/nm usage output
safe_arch() {
    local arch
    arch=$(current_arch)
    case "$arch" in
        *[!A-Za-z0-9_]*) arch="" ;;
    esac
    echo "$arch"
}

# Run otool honoring the currently selected architecture
otool_run() {
    local arch
    arch=$(safe_arch)
    if [ -n "$arch" ]; then
        "$OTOOL" -arch "$arch" "$@"
    else
        "$OTOOL" "$@"
    fi
}

# ──────────────────────────────────────────────────────────────
# Tab load-state tracking (binary|arch signature per tab)
# ──────────────────────────────────────────────────────────────

tab_sig()    { echo "$(current_binary)|$(current_arch)"; }
mark_loaded() { tab_sig > "$(state_dir)/loaded-$1.sig"; }
clear_loaded() { /bin/rm -f "$(state_dir)"/loaded-*.sig; }

# True if tab <key> is already populated for the current binary+arch
tab_fresh() {
    local f
    f="$(state_dir)/loaded-$1.sig"
    [ -f "$f" ] && [ "$(/bin/cat "$f")" = "$(tab_sig)" ]
}

# Map TabView tab index -> loader COMMAND_ID ("" = no loader)
tab_loader_for_index() {
    case "$1" in
        0) echo "OTool.libs.load" ;;
        1) echo "OTool.headers.load" ;;
        2) echo "OTool.loadcmds.load" ;;
        3) echo "OTool.sections.load" ;;
        4) echo "OTool.symbols.load" ;;
        5) echo "OTool.disasm.load" ;;
        *) echo "" ;;
    esac
}

# Reload the currently visible tab (after binary/arch change)
reload_current_tab() {
    local loader
    loader=$(tab_loader_for_index "$(current_tab)")
    [ -n "$loader" ] && "$next_cmd" "$cmd_guid" "$loader"
}

# ──────────────────────────────────────────────────────────────
# Header (binary name, icon, arch picker) — used by content.load
# and binary.selected
# ──────────────────────────────────────────────────────────────

update_binary_header() {
    local bin dir type archs count arch saved
    bin=$(current_binary)
    dir=$(state_dir)
    if [ -z "$bin" ]; then
        set_value "$HEADER_NAME_ID" "No Mach-O binaries found"
        set_value "$HEADER_PATH_ID" ""
        return 1
    fi

    type=$(classify_binary "$bin")
    set_value "$HEADER_NAME_ID" "$(/usr/bin/basename "$bin")"
    set_value "$HEADER_PATH_ID" "$(/usr/bin/dirname "$bin")"
    set_prop "$HEADER_ICON_ID" "systemName" "\"$(icon_for_type "$type")\""

    archs=$(detect_architectures "$bin")
    count=$(echo "$archs" | /usr/bin/wc -w | /usr/bin/tr -d ' ')
    echo "$archs" > "$dir/archs.txt"
    if [ "$count" -gt 1 ]; then
        # shellcheck disable=SC2086
        set_prop "$ARCH_PICKER_ID" "options" "$(json_array $archs)"
        saved=$(current_arch)
        host=$(/usr/bin/uname -m)
        if [ -n "$saved" ] && word_in_list "$saved" "$archs"; then
            arch="$saved"
        elif word_in_list "$host" "$archs"; then
            # Prefer the slice matching this machine
            arch="$host"
        elif [ "$host" = "arm64" ] && word_in_list "arm64e" "$archs"; then
            arch="arm64e"
        else
            arch=$(echo "$archs" | /usr/bin/awk '{print $1}')
        fi
        echo "$arch" > "$dir/arch.txt"
        # Pickers select by 1-based option index, not by name
        set_value "$ARCH_PICKER_ID" "$(list_index_of "$arch" "$archs")"
        set_visible "$ARCH_PICKER_ID" 1
    else
        echo "" > "$dir/arch.txt"
        set_visible "$ARCH_PICKER_ID" 0
    fi
    return 0
}

# ──────────────────────────────────────────────────────────────
# Window state seeding (discovery) — called from OTool.init
# (INIT_SUBCOMMAND_ID, runs before the window appears), with
# OTool.main.sh as a fallback caller
# ──────────────────────────────────────────────────────────────

# seed_window_state <dropped-path>
# Discovers Mach-O binaries and writes all per-window state files.
# binaries.tsv is written last (atomic mv) — it is the "discovery done"
# signal that wait_for_discovery polls for.
seed_window_state() {
    local obj="$1" dir list main_exe exe first tmp_tsv
    dir=$(state_dir)
    echo "0" > "$dir/curtab.txt"
    echo "$obj" > "$dir/obj.txt"
    : > "$dir/current.txt"
    echo "" > "$dir/arch.txt"

    list="$dir/found.txt"
    : > "$list"

    if [ -n "$obj" ] && [ -e "$obj" ]; then
        set_window_title "$(/usr/bin/basename "$obj")"
        if [ -f "$obj" ]; then
            if /usr/bin/file -b "$obj" 2>/dev/null | /usr/bin/grep -q "Mach-O"; then
                echo "$obj" >> "$list"
            fi
        elif [ -d "$obj" ]; then
            # Battle-tested pattern (codesign_applet.sh
            # sign_executables_in_dir): regular files only (-type f skips
            # framework symlinks, so no dedup needed), executable bit or
            # dylib/so/MacOS candidates, each verified as Mach-O via file(1).
            /usr/bin/find "$obj" -type f \
                \( -perm +111 -o -name '*.dylib' -o -name '*.so' -o -path '*/MacOS/*' \) \
                -print 2>/dev/null | /usr/bin/sort | while IFS= read -r f; do
                file_type=$(/usr/bin/file -b "$f" 2>/dev/null)
                case "$file_type" in
                    *Mach-O*) echo "$f" >> "$list" ;;
                esac
            done
        fi
    fi

    # Put the bundle's main executable first, the rest in path order
    main_exe=""
    if [ -d "$obj" ] && [ -f "$obj/Contents/Info.plist" ]; then
        exe=$(/usr/bin/plutil -extract CFBundleExecutable raw -o - \
            "$obj/Contents/Info.plist" 2>/dev/null)
        if [ -n "$exe" ] && [ -f "$obj/Contents/MacOS/$exe" ]; then
            main_exe="$obj/Contents/MacOS/$exe"
        fi
    fi

    # binaries.tsv: name \t type \t path (path = hidden 3rd table column)
    tmp_tsv="$dir/binaries.tsv.tmp"
    : > "$tmp_tsv"
    {
        [ -n "$main_exe" ] && echo "$main_exe"
        /usr/bin/grep -v -x -F "${main_exe:-__none__}" "$list"
    } | while IFS= read -r f; do
        [ -z "$f" ] && continue
        printf "%s\t%s\t%s\n" "$(/usr/bin/basename "$f")" "$(classify_binary "$f")" "$f"
    done >> "$tmp_tsv"

    first=$(/usr/bin/head -n 1 "$tmp_tsv" | /usr/bin/cut -f3)
    echo "$first" > "$dir/current.txt"
    /bin/mv "$tmp_tsv" "$dir/binaries.tsv"
}

# ──────────────────────────────────────────────────────────────
# otool -l parse cache (shared by Load Cmds, Sections, Libraries)
# ──────────────────────────────────────────────────────────────

# Parse otool -l output into TSV state files:
#   cmds.tsv               index \t cmd \t summary \t segname(LC_SEGMENT only)
#   fields-<index>.tsv     key \t value          (per load command)
#   segments.tsv           segname \t sect1,sect2,…
#   sections-<segname>.tsv sectname \t addr \t size \t offset \t align \t flags
#   rpaths.txt             one LC_RPATH path per line
parse_loadcmds() {
    local raw="$1" dir
    dir=$(state_dir)
    /bin/rm -f "$dir"/fields-*.tsv "$dir"/sections-*.tsv \
        "$dir/cmds.tsv" "$dir/segments.tsv" "$dir/rpaths.txt"
    /usr/bin/touch "$dir/cmds.tsv" "$dir/segments.tsv" "$dir/rpaths.txt"

    /usr/bin/awk -v dir="$dir" '
    function platname(p) {
        if (p == 1) return "macOS"
        if (p == 2) return "iOS"
        if (p == 3) return "tvOS"
        if (p == 4) return "watchOS"
        if (p == 5) return "bridgeOS"
        if (p == 6) return "Mac Catalyst"
        if (p == 7) return "iOS Simulator"
        if (p == 8) return "tvOS Simulator"
        if (p == 9) return "watchOS Simulator"
        if (p == 10) return "DriverKit"
        return "platform " p
    }
    # ── numeric constant / enum decoders (portable: no gawk strtonum/and/or) ──
    function hex2dec(s,   n, i, c, d) {
        sub(/^0[xX]/, "", s)
        n = 0
        for (i = 1; i <= length(s); i++) {
            c = tolower(substr(s, i, 1))
            if      (c >= "0" && c <= "9") d = c + 0
            else if (c == "a") d = 10
            else if (c == "b") d = 11
            else if (c == "c") d = 12
            else if (c == "d") d = 13
            else if (c == "e") d = 14
            else if (c == "f") d = 15
            else continue
            n = n * 16 + d
        }
        return n
    }
    function bit(v, b) { return int(v / b) % 2 }
    function vmprot(hex,   v) {
        v = hex2dec(hex)
        return (bit(v,1) ? "r" : "-") (bit(v,2) ? "w" : "-") (bit(v,4) ? "x" : "-")
    }
    function segflags(hex,   v, r) {
        v = hex2dec(hex); r = ""
        if (bit(v, 1))  r = r (r == "" ? "" : " ") "HIGHVM"
        if (bit(v, 2))  r = r (r == "" ? "" : " ") "FVMLIB"
        if (bit(v, 4))  r = r (r == "" ? "" : " ") "NORELOC"
        if (bit(v, 8))  r = r (r == "" ? "" : " ") "PROTECTED_V1"
        if (bit(v, 16)) r = r (r == "" ? "" : " ") "READ_ONLY"
        return (r == "" ? "none" : r)
    }
    function sectype(t) {
        if (t == 0)  return "Regular"
        if (t == 1)  return "Zerofill"
        if (t == 2)  return "C strings"
        if (t == 3)  return "4-byte literals"
        if (t == 4)  return "8-byte literals"
        if (t == 5)  return "Literal pointers"
        if (t == 6)  return "Non-lazy symbol pointers"
        if (t == 7)  return "Lazy symbol pointers"
        if (t == 8)  return "Symbol stubs"
        if (t == 9)  return "Mod init func pointers"
        if (t == 10) return "Mod term func pointers"
        if (t == 11) return "Coalesced"
        if (t == 12) return "GB zerofill"
        if (t == 13) return "Interposing"
        if (t == 14) return "16-byte literals"
        if (t == 15) return "DTrace DOF"
        if (t == 16) return "Lazy dylib symbol pointers"
        if (t == 17) return "Thread-local regular"
        if (t == 18) return "Thread-local zerofill"
        if (t == 19) return "Thread-local variables"
        if (t == 20) return "Thread-local var pointers"
        if (t == 21) return "Thread-local init func pointers"
        if (t == 22) return "Init func offsets"
        return "type " t
    }
    function sectflags(hex,   v, a) {
        v = hex2dec(hex); a = ""
        if (int(v / 2147483648) % 2) a = a (a == "" ? "" : "+") "pure-instr"     # 0x80000000
        if (int(v / 1073741824) % 2) a = a (a == "" ? "" : "+") "no-toc"         # 0x40000000
        if (int(v / 268435456)  % 2) a = a (a == "" ? "" : "+") "no-dead-strip"  # 0x10000000
        if (int(v / 67108864)   % 2) a = a (a == "" ? "" : "+") "self-modifying" # 0x04000000
        if (int(v / 33554432)   % 2) a = a (a == "" ? "" : "+") "debug"          # 0x02000000
        if (int(v / 1024)       % 2) a = a (a == "" ? "" : "+") "some-instr"     # 0x00000400
        return sectype(v % 256) (a == "" ? "" : " (" a ")")
    }
    function buildtool(n) {
        if (n == 1) return "clang"
        if (n == 2) return "swift"
        if (n == 3) return "ld"
        if (n == 4) return "lld"
        return "tool " n
    }
    # Append a decoded meaning to a raw field value where we recognize it
    function annotate(key, val) {
        if (key == "platform")
            return val "   (" platname(val + 0) ")"
        if (key == "tool" && cmdname == "LC_BUILD_VERSION")
            return val "   (" buildtool(val + 0) ")"
        if ((key == "maxprot" || key == "initprot") && cmdname ~ /^LC_SEGMENT/)
            return val "   (" vmprot(val) ")"
        if (key == "flags" && cmdname ~ /^LC_SEGMENT/)
            return val "   (" segflags(val) ")"
        if (key == "cryptid")
            return val "   (" (val == "0" ? "not encrypted" : "encrypted") ")"
        return val
    }
    function make_summary(   s) {
        if (cmdname ~ /^LC_SEGMENT/) s = segname "  (" nsects " sections)"
        else if (cmdname ~ /DYLIB/) s = f["name"]
        else if (cmdname == "LC_RPATH") s = f["path"]
        else if (cmdname == "LC_MAIN") s = "entryoff " f["entryoff"]
        else if (cmdname == "LC_UUID") s = f["uuid"]
        else if (cmdname == "LC_SOURCE_VERSION") s = f["version"]
        else if (cmdname == "LC_BUILD_VERSION")
            s = platname(f["platform"] + 0) "  minos " f["minos"] "  sdk " f["sdk"]
        else if (cmdname ~ /^LC_VERSION_MIN/) s = "version " f["version"] "  sdk " f["sdk"]
        else if (cmdname == "LC_SYMTAB") s = f["nsyms"] " symbols"
        else if (cmdname ~ /^LC_ENCRYPTION_INFO/)
            s = "cryptid " f["cryptid"] (f["cryptid"] == "0" ? "  (not encrypted)" : "")
        else if (f["dataoff"] != "") s = "dataoff " f["dataoff"]  "  size " f["datasize"]
        else s = ""
        return s
    }
    function flush_section(   sf, fl) {
        if (mode != "sect") return
        if (s["sectname"] != "" && s["segname"] != "") {
            sf = dir "/sections-" s["segname"] ".tsv"
            fl = s["flags"]
            if (fl != "") fl = fl "  (" sectflags(fl) ")"
            print s["sectname"] "\t" s["addr"] "\t" s["size"] "\t" s["offset"] "\t" s["align"] "\t" fl >> sf
        }
        mode = "cmd"
    }
    function flush_cmd() {
        if (idx == "") return
        printf "%s\t%s\t%s\t%s\n", idx, cmdname, make_summary(),
            (cmdname ~ /^LC_SEGMENT/ ? segname : "") >> (dir "/cmds.tsv")
        if (cmdname ~ /^LC_SEGMENT/ && segname != "")
            print segname "\t" sects >> (dir "/segments.tsv")
        close(dir "/fields-" idx ".tsv")
    }
    BEGIN { idx = ""; mode = "" }
    /^Load command [0-9]+/ {
        flush_section(); flush_cmd()
        idx = $3; mode = "cmd"
        cmdname = ""; segname = ""; nsects = ""; sects = ""
        delete f
        next
    }
    /^Section$/ {
        flush_section()
        mode = "sect"; delete s
        next
    }
    mode == "" { next }
    {
        line = $0
        sub(/^[ \t]+/, "", line)
        if (line == "") next
        if (match(line, /^(time stamp|current version|compatibility version) /)) {
            key = substr(line, 1, RLENGTH - 1)
            val = substr(line, RLENGTH + 1)
        } else {
            sp = index(line, " ")
            if (sp == 0) { key = line; val = "" }
            else {
                key = substr(line, 1, sp - 1)
                val = substr(line, sp + 1)
                sub(/^ +/, "", val)
            }
        }
        gsub(/ \(offset [0-9]+\)$/, "", val)
        if (mode == "cmd") {
            f[key] = val
            if (key == "cmd") cmdname = val
            if (key == "segname") segname = val
            if (key == "nsects") nsects = val
            print key "\t" annotate(key, val) >> (dir "/fields-" idx ".tsv")
            if (cmdname == "LC_RPATH" && key == "path")
                print val >> (dir "/rpaths.txt")
        } else {
            s[key] = val
            if (key == "sectname") sects = (sects == "" ? val : sects "," val)
        }
        next
    }
    END { flush_section(); flush_cmd() }
    ' "$raw"
}

# Run + parse otool -l for the current binary/arch unless already cached
ensure_loadcmds_parsed() {
    local dir bin sig
    dir=$(state_dir)
    bin=$(current_binary)
    [ -z "$bin" ] && return 1
    sig=$(tab_sig)
    if [ -f "$dir/parse.sig" ] && [ "$(/bin/cat "$dir/parse.sig")" = "$sig" ]; then
        return 0
    fi
    otool_run -l "$bin" > "$dir/loadcmds_raw.txt" 2>/dev/null
    parse_loadcmds "$dir/loadcmds_raw.txt"
    echo "$sig" > "$dir/parse.sig"
}

# One-line plain-English description for a load command name.
# Used by the Load Commands detail pane; the full HTML reference goes deeper.
lc_description() {
    case "$1" in
    LC_SEGMENT|LC_SEGMENT_64)
        echo "Defines a segment mapped into memory — its address range, file region, protections, and sections." ;;
    LC_SYMTAB)
        echo "Locates the symbol table (nlist entries) and the string table." ;;
    LC_DYSYMTAB)
        echo "Dynamic symbol table: groups local/defined/undefined symbols and indirect symbols for the dynamic linker." ;;
    LC_LOAD_DYLIB)
        echo "A dynamic library this binary links against (loaded at launch)." ;;
    LC_LOAD_WEAK_DYLIB)
        echo "A weakly-linked dynamic library — allowed to be missing at runtime." ;;
    LC_REEXPORT_DYLIB)
        echo "A dependent library whose symbols are re-exported as if they were defined here." ;;
    LC_LOAD_UPWARD_DYLIB)
        echo "An upward dependency, used to break a mutual link cycle between libraries." ;;
    LC_LAZY_LOAD_DYLIB)
        echo "A library loaded lazily, only when one of its symbols is first used." ;;
    LC_ID_DYLIB)
        echo "This file's own install name and version — it identifies this file as a dylib." ;;
    LC_LOAD_DYLINKER)
        echo "Path of the dynamic linker that loads this program (usually /usr/lib/dyld)." ;;
    LC_ID_DYLINKER)
        echo "Identifies this file as the dynamic linker and gives its install path." ;;
    LC_DYLD_INFO|LC_DYLD_INFO_ONLY)
        echo "Compressed dyld metadata: rebase, binding, weak/lazy binding, and exported symbols." ;;
    LC_DYLD_CHAINED_FIXUPS)
        echo "Modern chained-fixups format describing rebases and binds (replaces LC_DYLD_INFO)." ;;
    LC_DYLD_EXPORTS_TRIE)
        echo "Trie of exported symbols, used together with chained fixups." ;;
    LC_UUID)
        echo "Unique build identifier, used to match a binary with its debug symbols (dSYM)." ;;
    LC_BUILD_VERSION)
        echo "Target platform and the minimum OS / SDK version this was built against." ;;
    LC_VERSION_MIN_MACOSX|LC_VERSION_MIN_IPHONEOS|LC_VERSION_MIN_TVOS|LC_VERSION_MIN_WATCHOS)
        echo "Minimum OS version and SDK (older form, superseded by LC_BUILD_VERSION)." ;;
    LC_SOURCE_VERSION)
        echo "Version of the source code used to build this binary." ;;
    LC_MAIN)
        echo "Entry point: file offset of main() plus the initial stack size." ;;
    LC_UNIXTHREAD)
        echo "Initial thread register state and entry point (older executables)." ;;
    LC_THREAD)
        echo "Initial thread state, without allocating a stack." ;;
    LC_FUNCTION_STARTS)
        echo "Compressed table of function start addresses (used for symbolication)." ;;
    LC_DATA_IN_CODE)
        echo "Ranges of non-instruction data embedded inside code sections." ;;
    LC_CODE_SIGNATURE)
        echo "Location of the embedded code-signature blob." ;;
    LC_ENCRYPTION_INFO|LC_ENCRYPTION_INFO_64)
        echo "Range of the file encrypted by FairPlay DRM (cryptid 0 means not encrypted)." ;;
    LC_SEGMENT_SPLIT_INFO)
        echo "Info for splitting/rebasing the segment when building the dyld shared cache." ;;
    LC_DYLIB_CODE_SIGN_DRS)
        echo "Designated requirements of the linked libraries, recorded for code signing." ;;
    LC_RPATH)
        echo "A runpath search directory used to resolve @rpath-based library loads." ;;
    LC_LINKER_OPTION)
        echo "Linker options embedded by the compiler (e.g. -lfoo, -framework Bar)." ;;
    LC_LINKER_OPTIMIZATION_HINT)
        echo "Hints the linker uses to optimize instruction sequences." ;;
    LC_NOTE)
        echo "A named region of arbitrary data carried in the file." ;;
    LC_TWOLEVEL_HINTS)
        echo "Hints that speed up two-level-namespace symbol lookups." ;;
    LC_PREBOUND_DYLIB)
        echo "Prebinding information for a dependent library (legacy)." ;;
    LC_ROUTINES|LC_ROUTINES_64)
        echo "Address of a library initialization routine (legacy)." ;;
    LC_SUB_FRAMEWORK)
        echo "Marks this as a sub-framework of an umbrella framework." ;;
    LC_SUB_UMBRELLA)
        echo "Names an umbrella framework that re-exports this library." ;;
    LC_SUB_CLIENT)
        echo "Names a client allowed to link directly against this sub-framework." ;;
    LC_SUB_LIBRARY)
        echo "Names a sub-library of this umbrella library." ;;
    LC_FILESET_ENTRY)
        echo "An entry in a Mach-O fileset (e.g. inside a kernel collection)." ;;
    LC_PREPAGE|LC_SYMSEG|LC_IDENT|LC_FVMFILE)
        echo "Obsolete load command (legacy)." ;;
    "")
        echo "" ;;
    *)
        echo "Mach-O load command. See the Mach-O reference for details." ;;
    esac
}

# ──────────────────────────────────────────────────────────────
# Library path resolution (Libraries tab status markers)
# ──────────────────────────────────────────────────────────────

# Marker for a linked-library path:
#   ""  system (dyld shared cache)   ✓ found
#   ✗  not found                     ⚠ suspicious location
lib_status_marker() {
    local p="$1" bindir="$2" rel rp
    case "$p" in
        /usr/lib/*|/System/*)
            echo "" ;;
        @executable_path/*)
            rel="${p#@executable_path/}"
            [ -f "$bindir/$rel" ] && echo "✓" || echo "✗" ;;
        @loader_path/*)
            rel="${p#@loader_path/}"
            [ -f "$bindir/$rel" ] && echo "✓" || echo "✗" ;;
        @rpath/*)
            rel="${p#@rpath/}"
            while IFS= read -r rp; do
                [ -z "$rp" ] && continue
                rp="${rp//@executable_path/$bindir}"
                rp="${rp//@loader_path/$bindir}"
                if [ -f "$rp/$rel" ]; then
                    echo "✓"
                    return 0
                fi
            done < "$(state_dir)/rpaths.txt"
            echo "✗" ;;
        /tmp/*|/private/tmp/*|/private/var/tmp/*)
            [ -f "$p" ] && echo "⚠" || echo "✗" ;;
        /*)
            [ -f "$p" ] && echo "✓" || echo "✗" ;;
        *)
            echo "?" ;;
    esac
}

# ──────────────────────────────────────────────────────────────
# Sections tab: display one segment,section
# ──────────────────────────────────────────────────────────────

# display_section <segname> <sectname>
# Reformat `otool -s` output into a canonical hex + ASCII dump (the ASCII gutter
# otool omits). otool prints "<vmaddr> <byte> <byte> ..." in order, one byte per
# hex pair, so we keep its real VM addresses and just append the printable-ASCII
# rendering — no file-offset / fat-slice math needed. macOS awk lacks strtonum(),
# so convert hex by hand.
hex_ascii_dump() {
    /usr/bin/awk '
        function hv(c) { return index("0123456789abcdef", c) - 1 }
        function byte(s,   t) { t = tolower(s); return hv(substr(t,1,1)) * 16 + hv(substr(t,2,1)) }
        $1 ~ /^[0-9a-fA-F]+$/ && $2 ~ /^[0-9a-fA-F]+$/ && length($2) % 2 == 0 {
            hex = ""; ascii = ""
            for (i = 2; i <= NF; i++) {
                tok = $i
                # otool -s prints single bytes (x86_64) or little-endian words
                # (arm64, e.g. 614d534e == bytes 4e 53 4d 61); walk each token
                # right-to-left so the bytes come out in file order either way.
                for (j = length(tok) - 1; j >= 1; j -= 2) {
                    b = substr(tok, j, 2)
                    hex = hex b " "
                    v = byte(b)
                    ascii = ascii ((v >= 32 && v < 127) ? sprintf("%c", v) : ".")
                }
            }
            printf "%s  %-48s |%s|\n", $1, hex, ascii
            next
        }
        { print }
    '
}

display_section() {
    local seg="$1" sect="$2" dir bin out info
    dir=$(state_dir)
    bin=$(current_binary)
    if [ -z "$bin" ] || [ -z "$seg" ] || [ -z "$sect" ]; then
        return 1
    fi

    set_visible "$SEC_PROGRESS_ID" 1
    if [ "$seg" = "__TEXT" ] && [ "$sect" = "__text" ]; then
        otool_run -tV "$bin" 2>&1 | /usr/bin/head -n "$MAX_TEXT_LINES" > "$dir/sections_out.txt"
    else
        otool_run -s "$seg" "$sect" "$bin" 2>&1 | hex_ascii_dump | /usr/bin/head -n "$MAX_TEXT_LINES" > "$dir/sections_out.txt"
    fi
    set_value "$SEC_EDITOR_ID" "$(/bin/cat "$dir/sections_out.txt")"
    dbg "section $seg,$sect -> sample: $(/usr/bin/sed -n '3p' "$dir/sections_out.txt")"

    info=$(/usr/bin/awk -F '\t' -v s="$sect" '$1 == s { print "addr: " $2 "   size: " $3; exit }' \
        "$dir/sections-$seg.tsv" 2>/dev/null)
    set_value "$SEC_STATUS_ID" "$info"
    set_visible "$SEC_PROGRESS_ID" 0
}

# Repopulate the Section picker for a segment; echoes the auto-selected
# section. Called in command substitution, so UI tool calls are silenced —
# their stdout would pollute the captured value.
populate_section_picker() {
    local seg="$1" dir sects first pick
    dir=$(state_dir)
    sects=$(/usr/bin/cut -f1 "$dir/sections-$seg.tsv" 2>/dev/null)
    if [ -z "$sects" ]; then
        set_prop "$SEC_SECT_PICKER_ID" "options" '[]' > /dev/null
        echo ""
        return 1
    fi
    # shellcheck disable=SC2086
    set_prop "$SEC_SECT_PICKER_ID" "options" "$(json_array $sects)" > /dev/null
    first=$(echo "$sects" | /usr/bin/head -n 1)
    pick="$first"
    if [ "$seg" = "__TEXT" ]; then
        case "$sects" in *__text*) pick="__text" ;; esac
    fi
    # Pickers select by 1-based option index, not by name
    set_value "$SEC_SECT_PICKER_ID" "$(list_index_of "$pick" "$(echo $sects)")" > /dev/null
    echo "$pick"
}

# ──────────────────────────────────────────────────────────────
# Symbols tab: filtered table refresh
# ──────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────
# Symbol demangling (Symbols tab)
# ──────────────────────────────────────────────────────────────

# Classify a (linker-decorated) symbol name: prints  swift | c++ | c
# On Darwin every symbol carries one extra leading underscore from the linker,
# so C++ Itanium "_Z…" shows as "__Z…" and Swift "$s…" shows as "_$s…".
symbol_language() {
    case "$1" in
        '_$s'*|'_$S'*|'_$e'*|'$s'*|'$S'*|'$e'*) echo swift ;;   # Swift 4.2+/5 mangling
        '__Z'*|'_Z'*|'___Z'*)                   echo "c++" ;;   # Itanium C++ ABI
        '_OBJC_'*|'__OBJC_'*)                    echo objc ;;   # Obj-C metadata symbols
        '_objc_msgSend'*'$'*)                    echo objc ;;   # Obj-C selector stubs
        *)                                       echo c ;;      # plain C (not mangled)
    esac
}

# Human-readable label for a language code
symbol_language_label() {
    case "$1" in
        swift) echo "Swift" ;;
        "c++") echo "C++" ;;
        objc)  echo "Obj-C" ;;
        *)     echo "C" ;;
    esac
}

# Locate the demangling tools at run time. Each prints the tool's path, or
# nothing if it is not installed — so handlers can tell the user what to add.
#   c++filt        ships with the Xcode Command Line Tools
#   swift-demangle ships with Xcode / a Swift toolchain (found via xcrun)
cxxfilt_tool() { [ -x "$CXXFILT" ] && printf '%s' "$CXXFILT"; }

swift_demangle_tool() {
    local sd
    [ -x "$XCRUN" ] || return 0
    sd=$("$XCRUN" -f swift-demangle 2>/dev/null) || return 0
    [ -n "$sd" ] && [ -x "$sd" ] && printf '%s' "$sd"
}

# ── Objective-C "demangling" ───────────────────────────────────
# Obj-C symbols aren't mangled, but the compiler/runtime name them by a fixed
# convention (there is no official Obj-C demangler). Recognize the common shapes
# and describe them in plain language. Names carry the Darwin leading underscore.
objc_tail() { printf '%s' "${1##*\$_}"; }   # the name after the "$_" separator

objc_demangle() {
    local s="$1" t
    case "$s" in
        # Selector stubs (-fobjc-msgsend-selector-stubs): _objc_msgSend$selector
        _objc_msgSendSuper2\$*|_objc_msgSendSuper\$*)
            t=${s#*\$}; printf 'objc_msgSendSuper selector — %s' "${t%%\$_OBJC_CLASS_*}" ;;
        _objc_msgSend*\$*)
            t=${s#*\$}; printf 'objc_msgSend selector — %s' "${t%%\$_OBJC_CLASS_*}" ;;

        # Class / metaclass objects and read-only metadata
        _OBJC_CLASS_\$_*)          printf 'class object — %s' "$(objc_tail "$s")" ;;
        _OBJC_METACLASS_\$_*)      printf 'metaclass — %s' "$(objc_tail "$s")" ;;
        __OBJC_CLASS_RO_\$_*)      printf 'class metadata (RO) — %s' "$(objc_tail "$s")" ;;
        __OBJC_METACLASS_RO_\$_*)  printf 'metaclass metadata (RO) — %s' "$(objc_tail "$s")" ;;
        _OBJC_EHTYPE_\$_*)         printf 'exception type — %s' "$(objc_tail "$s")" ;;

        # Ivar offset:  _OBJC_IVAR_$_Class.ivar
        _OBJC_IVAR_\$_*)
            t=$(objc_tail "$s")
            printf 'ivar %s of class %s' "${t#*.}" "${t%%.*}" ;;

        # Protocols (these use the "$_"-before-name form, so objc_tail extracts it)
        _OBJC_PROTOCOL_\$_*|__OBJC_PROTOCOL_\$_*)
            printf 'protocol — %s' "$(objc_tail "$s")" ;;
        _OBJC_LABEL_PROTOCOL_\$_*|__OBJC_LABEL_PROTOCOL_\$_*)
            printf 'protocol label — %s' "$(objc_tail "$s")" ;;
        _OBJC_PROTOCOL_REFERENCE_\$_*|__OBJC_PROTOCOL_REFERENCE_\$_*)
            printf 'protocol reference — %s' "$(objc_tail "$s")" ;;
        _OBJC_CLASS_PROTOCOLS_\$_*|__OBJC_CLASS_PROTOCOLS_\$_*)
            printf 'adopted protocols of %s' "$(objc_tail "$s")" ;;

        # Method / property / ivar / protocol lists:  __OBJC_$_<KIND>_<Name>
        __OBJC_\$_INSTANCE_METHODS_*)          printf 'instance methods of %s' "${s#__OBJC_\$_INSTANCE_METHODS_}" ;;
        __OBJC_\$_CLASS_METHODS_*)             printf 'class methods of %s' "${s#__OBJC_\$_CLASS_METHODS_}" ;;
        __OBJC_\$_INSTANCE_VARIABLES_*)        printf 'ivars of %s' "${s#__OBJC_\$_INSTANCE_VARIABLES_}" ;;
        __OBJC_\$_PROP_LIST_*)                 printf 'properties of %s' "${s#__OBJC_\$_PROP_LIST_}" ;;
        __OBJC_\$_CLASS_PROP_LIST_*)           printf 'class properties of %s' "${s#__OBJC_\$_CLASS_PROP_LIST_}" ;;
        __OBJC_\$_CLASS_PROTOCOLS_*)           printf 'adopted protocols of %s' "${s#__OBJC_\$_CLASS_PROTOCOLS_}" ;;
        __OBJC_\$_PROTOCOL_INSTANCE_METHODS_*) printf 'protocol instance methods of %s' "${s#__OBJC_\$_PROTOCOL_INSTANCE_METHODS_}" ;;
        __OBJC_\$_PROTOCOL_CLASS_METHODS_*)    printf 'protocol class methods of %s' "${s#__OBJC_\$_PROTOCOL_CLASS_METHODS_}" ;;
        __OBJC_\$_PROTOCOL_METHOD_TYPES_*)     printf 'protocol method types of %s' "${s#__OBJC_\$_PROTOCOL_METHOD_TYPES_}" ;;
        __OBJC_\$_PROTOCOL_REFS_*)             printf 'incorporated protocols of %s' "${s#__OBJC_\$_PROTOCOL_REFS_}" ;;

        # Categories:  __OBJC_$_CATEGORY[_<KIND>]_<Class>_$_<Category>
        __OBJC_\$_CATEGORY_INSTANCE_METHODS_*) printf 'category instance methods' ;;
        __OBJC_\$_CATEGORY_CLASS_METHODS_*)    printf 'category class methods' ;;
        __OBJC_\$_CATEGORY_*)                  printf 'category metadata' ;;

        *) printf 'Objective-C runtime symbol' ;;
    esac
}

# refresh_symbols <query> <kind: all|defined|undef|indirect>
refresh_symbols() {
    local q="$1" kind="$2" dir src total shown tmp
    dir=$(state_dir)
    case "$kind" in
        indirect) src="$dir/indirect.tsv" ;;
        *)        src="$dir/symbols.tsv" ;;
    esac
    [ -f "$src" ] || return 1

    tmp="$dir/symfilter.tsv"
    /usr/bin/awk -F '\t' -v kind="$kind" -v q="$(echo "$q" | /usr/bin/tr 'A-Z' 'a-z')" '
        kind == "defined"  && $2 ~ /^[Uu]$/ { next }
        kind == "undef"    && $2 !~ /^[Uu]$/ { next }
        kind == "exported" && ($2 !~ /^[A-Z]$/ || $2 == "U") { next }
        q != "" && index(tolower($0), q) == 0 { next }
        { print }
    ' "$src" > "$tmp"

    total=$(/usr/bin/wc -l < "$tmp" | /usr/bin/tr -d ' ')
    /usr/bin/head -n "$MAX_TABLE_ROWS" "$tmp" | feed_table "$SYM_TABLE_ID"
    if [ "$total" -gt "$MAX_TABLE_ROWS" ]; then
        shown="$MAX_TABLE_ROWS"
    else
        shown="$total"
    fi
    set_value "$SYM_STATUS_ID" "$shown of $total symbols"
}

# ──────────────────────────────────────────────────────────────
# Disassembly (master/detail: function list -> scoped disassembly)
# ──────────────────────────────────────────────────────────────

# From otool -tV output ($1), emit one function name per line. A function begins
# at a non-indented label line ("name:") immediately followed by an instruction
# line ("hex<TAB>..."); that lookahead skips the "<path> (architecture x):" and
# section headers, which also end in ":".
disasm_build_funcs() {
    /usr/bin/awk '
        /^[0-9a-fA-F]+\t/ { if (pend != "") { print pend; pend = "" } next }
        /^[^ \t].*:[ \t]*$/ { pend = $0; sub(/[ \t]*:[ \t]*$/, "", pend); next }
        { pend = "" }
    ' "$1"
}

# Print the disassembly block for exactly one function name ($2) out of file $1.
disasm_extract_func() {
    /usr/bin/awk -v want="$2" '
        /^[^ \t].*:[ \t]*$/ {
            nm = $0; sub(/[ \t]*:[ \t]*$/, "", nm)
            if (inblk) exit                 # reached the next function
            if (nm == want) { inblk = 1; print }
            next
        }
        inblk { if ($0 ~ /^[0-9a-fA-F]+\t/) print; else exit }
    ' "$1"
}

# Filter the cached function list by substring ($1) and feed the function table.
refresh_disasm_funcs() {
    local q="$1" dir tmp total shown
    dir=$(state_dir)
    [ -f "$dir/disasm_funcs.tsv" ] || return 1
    tmp="$dir/disasm_funcs_filtered.tsv"
    /usr/bin/awk -v q="$(echo "$q" | /usr/bin/tr 'A-Z' 'a-z')" '
        q != "" && index(tolower($0), q) == 0 { next }
        { print }
    ' "$dir/disasm_funcs.tsv" > "$tmp"
    total=$(/usr/bin/wc -l < "$tmp" | /usr/bin/tr -d ' ')
    /usr/bin/head -n "$MAX_TABLE_ROWS" "$tmp" | feed_table "$DIS_FUNCS_TABLE_ID"
    if [ "$total" -gt "$MAX_TABLE_ROWS" ]; then shown="$MAX_TABLE_ROWS"; else shown="$total"; fi
    set_value "$DIS_STATUS_ID" "$shown of $total functions"
}
