# skit Architecture

## Purpose

Define the implemented structure for a portable collection of Swift
command-line utilities that preserves behavior established by `queone/rkit`.

## System Summary

One root SwiftPM package exposes the `dos2unix` and `tree` executable products.
Each command owns its parser, filesystem behavior, rendering, and process
boundary. `SkitSupport` contains only strict raw-argument decoding,
terminal-style detection, and the shared release version.

## Current Platform

- Swift

## Major Components

- `Dos2Unix`: byte-preserving preview and in-place CRLF conversion.
- `Tree`: buffered filesystem traversal and deterministic rendering.
- `SkitSupport`: raw arguments, terminal styling, and version output.
- `Dos2UnixTests`: argument, byte, filesystem, metadata, and failure coverage.
- `TreeTests`: traversal, ordering, path, symlink, rendering, and failure
  coverage.
- `SkitSupportTests`: strict UTF-8 and terminal-policy coverage.
- `Tests/cli_integration.sh`: built-process stream, exit, and filesystem checks.
- `Tests/release_prep.sh`: package-shape and marked-version regression checks.

## Core Files

- `AGENTS.md`: base governance contract
- `plan.md`: prioritized roadmap and approved direction
- `build.sh`: canonical SwiftPM build, test, install, and release script
- `govna/development-cycle.md`: workflow from roadmap through release
- `govna/ac-template.md`: acceptance-criteria template for new work
- `govna/build-release.md`: build, test, and release rules

## Data And Control Flow

- Decode raw `argc` and `argv` through `SkitSupport`.
- Route decoded arguments into the selected executable target.
- Buffer successful command output before writing it once.
- Route successful output to stdout.
- Route diagnostics and recoverable tree warnings to stderr.
- Keep filesystem mutation inside `Dos2Unix`.
- Keep directory traversal inside `Tree`.

## Architecture Notes

- Use `queone/rkit` as the behavioral reference for `dos2unix` and `tree`.
- Pin the inspected `queone/rkit` release or commit in each utility AC.
- Support macOS 13 or newer.
- Use Ubuntu 24.04 x86_64 with Swift 6.x as the Linux reference environment.
- Allow Swift-toolchain modules shipped by Apple, including Foundation.
- Prohibit third-party packages by default.
- Update the unique marked version in `SkitSupport` during release prep.
- Keep Govna outside utility runtime behavior.

## Conventions

- Update this document when architecture or major workflow changes materially.
- Keep implementation detail in code and stable architecture here.
