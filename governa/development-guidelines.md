# Development Guidelines

Engineering guidance for any agent or contributor working in this repo.
These are durable coding practices, not workflow or process rules.
For workflow, see `development-cycle.md`. For validation, see `build-release.md`.
Sections above ## Project Practices are governa-maintained canon and update via canon syncs; repo-specific practices in ## Project Practices.

## Identifier Strategy

- Choose a primary key strategy early and document it in `arch.md`
- Prefer surrogate keys for internal identity; keep external IDs as indexed attributes
- When integrating multiple external ID systems, maintain an explicit mapping layer rather than assuming IDs are interchangeable

## Schema And Data Migrations

- Treat schema changes as first-class events: version them, document them, test the migration path
- Never assume old data fits new schemas — write migration logic or fail explicitly
- When a migration changes identity or key structure, audit all foreign key references in the same change

## External Integration Patterns

- Validate external data at the boundary; do not trust upstream shape or completeness
- When reconciling data from multiple sources, define a clear precedence order and document it
- Cache external data locally with explicit TTL or versioning; never silently serve stale data as fresh

## Generated Artifact Propagation

- When source-of-truth code is duplicated into templates or rendered examples, fixes must propagate to all copies in the same change
- Grep the full repo for the pattern being changed before considering a fix complete
- If a template and its rendered output diverge, the template is authoritative
- Keep `build.sh` self-contained; do not add sourced production helper modules.
- Propagate stack build behavior through the affected template under `internal/templates/overlays/code/stacks/`.

## Error Handling And Validation

- Validate at system boundaries (user input, external APIs, file I/O); trust internal code
- Fail explicitly rather than silently degrading — a clear error is better than wrong output
- Static analysis and linting errors are build failures, not warnings
- Validate installable-target declarations before compiling or installing them.

## Testing Expectations

- Tests are part of implementation, not a follow-up step
- Every new function and error path should have a test before the work is presented as complete
- If a code path cannot be tested without mocking infrastructure that is out of scope, document the coverage gap explicitly rather than silently skipping it
- Label tests that require live systems or manual verification as `[Manual]`

## Dependency And Import Hygiene

- Prefer standard library over external dependencies when the capability is equivalent
- When adding a dependency, justify it — convenience alone is not sufficient
- Keep import paths consistent after renames or reorganizations

## CLI Usage Formatting

- All commands must accept `-h`, `-?`, and `--help` as help flags
- Help output uses a shared formatting function for consistent layout
- "Usage:" is rendered in bold white
- Each flag line is indented 2 spaces; descriptions align at column 38
- Short and long flag forms are combined on one line (e.g. `-v, --verbose`)
- When adding new flags, add the entry to the shared usage formatter — do not rely on framework defaults

## Documentation Alignment

- Docs ship with the code change that introduces the behavior
- If a doc references a function, flag, or file path, verify it still exists before publishing
- Architecture docs (`arch.md`) reflect what is built, not what is planned

## Swift Practices

- Run all repository validation through `./build.sh`.
- Require Swift 6.0 or newer.
- Declare public executables as explicit SwiftPM executable products.
- Keep `Package.resolved` tracked for leaf packages with dependencies.
- Treat `Package.resolved` as optional for dependency libraries.
- Keep project-level `.swiftpm/` configuration tracked.
- Format Swift code with the toolchain-provided formatter.
- Treat formatter findings and compiler warnings as failures.
- Document public APIs with documentation comments.
- Avoid Xcode-only assumptions in cross-platform SwiftPM code.
- Set `SWIFT_BIN_HOME` to an absolute external bin directory when overriding `$HOME/.local/bin`.
- Declare every installable command as an executable product.
- Pass space-separated executable-product names to `./build.sh` for scoped builds.
- Keep formatting and tests package-wide during scoped builds.

## Project Practices

- Follow existing repo patterns unless an approved improvement says otherwise.
