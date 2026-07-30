# skit

`skit` is a collection of portable command-line utilities implemented as one
Swift package. It includes `dos2unix` for previewing or converting CRLF line
endings and `tree` for rendering directory hierarchies.

## Why

The project brings the established behavior of `queone/rkit` v1.2.0 at commit
`e9d11281189dea2c2491ec81461018258e0e9dc1` to Swift while keeping each command
independently organized. It supports macOS 13 or newer and targets Ubuntu 24.04
x86_64 with Swift 6.x as its Linux reference environment.

## Build

Install Swift 6 or newer, Git, and Bash 3.2 or newer, then run:

```bash
./build.sh
```

The canonical build formats, compiles, and tests the package; runs CLI and
release-prep regression suites; creates release binaries in an external scratch
directory; and installs `dos2unix` and `tree` in
`${SWIFT_BIN_HOME:-$HOME/.local/bin}`.

Pass one or both product names to limit product builds and installation while
retaining package-wide formatting and tests:

```bash
./build.sh dos2unix
./build.sh tree
./build.sh dos2unix tree
```

## Architecture

The root SwiftPM package declares separate `dos2unix` and `tree` executable
products. `SkitSupport` shares strict process-argument decoding, terminal
styling, and release-version output. The package uses only Swift-toolchain
modules shipped by Apple, including Foundation; it has no third-party
dependencies.

## dos2unix

```text
dos2unix [options] [--] FILE

  -f, --force    Convert CRLF pairs to LF in place
  -v, --version  Print version and exit
  -h, -?, --help Show help and exit
  --             End option parsing
```

Without `--force`, the command leaves `FILE` unchanged and displays every CRLF
pair as visible `\r\n` text. Every other byte, including lone CR and non-UTF-8
content, passes through unchanged.

With `--force`, the command replaces CRLF pairs with LF through the existing
file handle. Successful conversion preserves inode identity, hard-link
visibility, symlink operands, and Unix mode bits where supported. Open,
inspection, and initial-read failures leave the file unchanged. A write failure
after truncation can leave a partial file; restore it from backup or source
control before retrying.

## tree

```text
tree [options] [directory]

  -f, --full-path  Show each file's path joined to the directory operand
  -v, --version    Print version and exit
  -h, -?, --help   Show help and exit
  --               End option parsing
```

The directory defaults to `.` and is omitted from output. Entries include
dotfiles and are sorted by UTF-8 bytes. Descendant directory symlinks are
printed without traversal. An unreadable root fails; an unreadable descendant
remains visible, emits a warning, and does not prevent other readable entries
from rendering.

Use `--full-path` to display lexically cleaned paths for files. Relative roots
produce relative paths and absolute roots produce absolute paths.

## Color

Both commands emit color only when stdout is a compatible terminal. Set
`NO_COLOR`, use `TERM=dumb`, or redirect stdout for plain output.

## Governance

This repo is governed by an explicit session-entry contract for AI coding agents — see [`governa/operator-contract-rationale.md`](governa/operator-contract-rationale.md) for the design reasoning and [`AGENTS.md`](AGENTS.md) for the operational rules.
