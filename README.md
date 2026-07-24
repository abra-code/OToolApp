# OTool

A native macOS GUI front-end for `otool` — a structured, searchable Mach-O binary inspector. Drop an app, framework, or binary on OTool and it discovers every Mach-O inside, then presents the most useful `otool` outputs (linked libraries, load commands, headers, sections, disassembly, and symbols) in a multi-tab window.

**Requires macOS 14.6 (Sonoma) or later.**

---

## Overview

Drop a file or bundle onto the OTool app icon (or use Finder's Open With); each dropped item opens its own independent window. Launching OTool plain presents an open panel instead. The window discovers every Mach-O binary inside the dropped item, lists them in a searchable left sidebar, and shows structured `otool` output for the selected binary on the right. For fat (universal) binaries, an architecture picker selects which slice to inspect.

---

## Requirements

| Requirement | Notes |
|---|---|
| macOS 14.6+ | Sonoma minimum |
| Xcode Command Line Tools | Provides `otool`, `nm`, `lipo`, `size`, `swift-demangle`, and `c++filt`. Install with `xcode-select --install` (or a full Xcode). OTool bundles no binaries of its own. |

---

## Supported Input

| Input | Discovery |
|---|---|
| `.app` / `.framework` / `.bundle` / `.plugin` / `.kext` | Recursive scan for Mach-O binaries; the bundle's `CFBundleExecutable` is listed first |
| Standalone binary / `.dylib` / `.so` | Used directly |

Discovery lists regular Mach-O files only, so framework symlinks (for example `Foo.framework/Foo`) do not duplicate the versioned binary. Each candidate is verified with `file` before being added.

---

## Tabs

| Tab | Shows | Underlying tool |
|---|---|---|
| **Libraries** | Linked dynamic libraries, the install name, and resolved `@rpath` / `@loader_path` references | `otool -L` / `-D` |
| **Load Cmds** | Parsed load commands (segments, dylib references, version and entry-point info, and more) | `otool -l` |
| **Headers** | Mach header flags and, for fat binaries, per-slice detail | `otool -hv`, `lipo -detailed_info` |
| **Sections** | Segment / section contents; hex or disassembly for `__TEXT,__text` | `otool -s` / `-tV` |
| **Disasm** | Disassembly of the text section | `otool -tV` |
| **Symbols** | The symbol table and indirect (stub / GOT) symbols, filterable by All, Defined, Exported, Undefined (imported), or Indirect | `nm`, `otool -Iv` |

Every tab has a filter field for searching its output in real time. C++ and Swift symbol names are demangled with `c++filt` and `swift-demangle`. Output can be copied, and the selected binary revealed in Finder.

---

## Architecture Selection

For fat (universal) binaries, a segmented picker in the content header exposes every slice, populated from `lipo -archs`. The host architecture (`uname -m`, with an `arm64e`-only slice accepted on an arm64 host) is preselected, falling back to the first slice. The chosen architecture is remembered per window and passed to every `otool` invocation, so all tabs reflect the same slice. The picker is hidden for thin binaries.

---

## Architecture

OTool is an OMC applet. The OMC framework handles the app lifecycle, per-item windows, the open panel, and Finder integration. The UI is defined declaratively in ActionUI JSON (`OTool.json`, `Sidebar.json`, `Content.json`, and one `Tab*.json` per tab). All business logic runs as shell scripts in `Contents/Resources/Scripts/`, with shared discovery and tool-invocation helpers in `lib.otool.sh`.

Multiple dropped items are handled separately, so each gets its own command invocation and window. Command routing (sidebar load and filtering, per-tab load and filtering, architecture change, binary selection, copy, reveal) is declared in `Contents/Resources/Command.json`.

---

## Building and Signing

The app runs as-is; it invokes the system command-line tools and bundles nothing to build. After changing scripts or UI JSON, re-sign the bundle so the signature stays valid:

```bash
./codesign_applet.sh OTool.app -                                    # ad-hoc (local use)
./codesign_applet.sh OTool.app "Developer ID Application: ..."       # for distribution
```

Developer ID signing enables the hardened runtime and a timestamp; for distribution the app should then be notarized with `xcrun notarytool`.

---

## License

OTool is licensed under the Apache License 2.0 — see [LICENSE](LICENSE).
