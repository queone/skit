# skit Plan

## Product Direction

Build a portable collection of command-line utilities as one root SwiftPM
package with separate executable products. Begin with `dos2unix` and `tree`,
using pinned `queone/rkit` revisions as their behavioral references and
targeting macOS and Linux.

## Ideas To Explore

Ideas captured for future reference. A bullet list — each line starts with `- IE<N>: ` (sequential N) for stable references. Two kinds: (a) **pre-rubric IE** — `IE<N>: <one-liner>`, awaiting director discussion and the objective-fit rubric (see `AGENTS.md` Approval Boundaries); (b) **AC-pointer** — `IE<N>: <one-liner> → govna/ac<N>-<slug>.md`, pointing at a drafted AC stub not yet through critique. A pre-rubric entry that clears the rubric converts to an AC-pointer at AC-draft time, keeping its `IE<N>` number. Remove entries when the idea is rejected, retired, or (for AC-pointers) the AC has shipped and its file deleted. Not a historical record.

- IE2: Run post-release verification on Ubuntu 24.04 x86_64 with Swift 6.x.
