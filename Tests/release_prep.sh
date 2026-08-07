#!/usr/bin/env bash
set -euo pipefail

source_build=$1

fail() {
  printf 'release prep regression: %s\n' "$1" >&2
  exit 1
}

fixture=$(mktemp -d "${TMPDIR:-/tmp}/skit-prep.XXXXXX")
trap 'rm -rf "$fixture"' EXIT HUP INT TERM

package_json="$fixture/package.json"
swift package dump-package >"$package_json"
package_validator="$fixture/package-validator.swift"
cat >"$package_validator" <<'SWIFT'
import Foundation

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data(("package contract: " + message + "\n").utf8))
  exit(1)
}

guard CommandLine.arguments.count == 2 else {
  fail("expected package JSON path")
}
let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
guard let package = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let products = package["products"] as? [[String: Any]],
      let targets = package["targets"] as? [[String: Any]],
      let dependencies = package["dependencies"] as? [Any],
      let platforms = package["platforms"] as? [[String: Any]] else {
  fail("malformed package JSON")
}
let executables = products.compactMap { product -> String? in
  guard let type = product["type"] as? [String: Any],
        type.keys.contains("executable") else {
    return nil
  }
  return product["name"] as? String
}.sorted()
guard executables == ["dos2unix", "tree"] else {
  fail("executable products differ")
}
guard targets.filter({ $0["type"] as? String == "test" }).count == 3 else {
  fail("test target count differs")
}
guard dependencies.isEmpty else {
  fail("external dependencies present")
}
guard platforms.contains(where: {
  $0["platformName"] as? String == "macos" && $0["version"] as? String == "13.0"
}) else {
  fail("macOS minimum differs")
}
SWIFT
swift "$package_validator" "$package_json" || fail 'Package.swift contract differs'

mkdir -p "$fixture/Sources/SkitSupport" "$fixture/govna"
cp "$source_build" "$fixture/build.sh"
chmod +x "$fixture/build.sh"

cat >"$fixture/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "fixture")
SWIFT
cat >"$fixture/Sources/SkitSupport/Version.swift" <<'SWIFT'
public enum SkitVersion {
    public static let current = "0.1.0"  // govna: release-version
    public static let unrelated = "9.9.9"
}
SWIFT
cat >"$fixture/CHANGELOG.md" <<'MARKDOWN'
# Changelog

| Version | Summary |
|---------|---------|
| Unreleased | |
MARKDOWN
cat >"$fixture/plan.md" <<'MARKDOWN'
# Plan
- IE9: fixture → govna/ac9-fixture.md
MARKDOWN
printf '# AC9\n' >"$fixture/govna/ac9-fixture.md"

git -C "$fixture" init -q

cp "$fixture/Sources/SkitSupport/Version.swift" "$fixture/version.before"
(
  cd "$fixture"
  ./build.sh prep --dry-run v0.2.0 'AC9: fixture' >/dev/null
)
cmp "$fixture/version.before" "$fixture/Sources/SkitSupport/Version.swift" ||
  fail 'dry-run changed version source'

(
  cd "$fixture"
  ./build.sh prep --no-build v0.2.0 'AC9: fixture' >/dev/null
)
grep -Eq 'current = "0\.2\.0"[[:space:]]+// govna: release-version' \
  "$fixture/Sources/SkitSupport/Version.swift" || fail 'version was not updated'
grep -q 'unrelated = "9\.9\.9"' "$fixture/Sources/SkitSupport/Version.swift" ||
  fail 'unrelated Swift text changed'
[ ! -e "$fixture/govna/ac9-fixture.md" ] || fail 'referenced Govna AC was not deleted'
! grep -q 'govna/ac9-fixture.md' "$fixture/plan.md" ||
  fail 'matching Govna AC pointer was not removed'

printf '%s\n' 'public static let other = "0.2.0" // govna: release-version' \
  >>"$fixture/Sources/SkitSupport/Version.swift"
set +e
(
  cd "$fixture"
  ./build.sh prep --dry-run v0.3.0 'fixture' >/dev/null 2>&1
)
status=$?
set -e
[ "$status" -ne 0 ] || fail 'duplicate marker was accepted'

cat >"$fixture/Sources/SkitSupport/Version.swift" <<'SWIFT'
public enum SkitVersion {
    public static let current = "invalid"  // govna: release-version
}
SWIFT
set +e
(
  cd "$fixture"
  ./build.sh prep --dry-run v0.3.0 'fixture' >/dev/null 2>&1
)
status=$?
set -e
[ "$status" -ne 0 ] || fail 'malformed marker was accepted'

printf 'public enum SkitVersion {}\n' >"$fixture/Sources/SkitSupport/Version.swift"
set +e
(
  cd "$fixture"
  ./build.sh prep --dry-run v0.3.0 'fixture' >/dev/null 2>&1
)
status=$?
set -e
[ "$status" -ne 0 ] || fail 'missing marker was accepted'
