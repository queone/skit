#!/usr/bin/env bash
set -euo pipefail

dos2unix_bin=$1
tree_bin=$2

fail() {
  printf 'cli integration: %s\n' "$1" >&2
  exit 1
}

[ -x "$dos2unix_bin" ] || fail 'dos2unix binary is not executable'
[ -x "$tree_bin" ] || fail 'tree binary is not executable'

fixture=$(mktemp -d "${TMPDIR:-/tmp}/skit-cli.XXXXXX")
trap 'rm -rf "$fixture"' EXIT HUP INT TERM

cat >"$fixture/dos2unix-help" <<'TEXT'
dos2unix v0.1.2
Preview or convert CRLF line endings — https://github.com/queone/skit
Usage
  dos2unix [options] [--] FILE

  Preview FILE and display each CRLF pair as visible \r\n text.
  Use -- before a FILE whose name begins with a dash.

Options
  -f, --force    Convert CRLF pairs to LF in place
  -v, --version  Print version and exit
  -h, -?, --help Show this help message and exit
  --             End option parsing
TEXT
cat >"$fixture/tree-help" <<'TEXT'
tree v0.1.2
Directory tree printer — https://github.com/queone/skit
Usage
  tree [options] [directory]

  Options can appear before or after directory operands. The last directory
  operand is used. Use -- before a directory whose name begins with a dash.

Options
  -f, --full-path  Show each file's path joined to the directory operand
  -v, --version    Print version and exit
  -h, -?, --help   Show this help message and exit
  --               End option parsing

Examples
  tree
  tree -f /path/to/directory
  tree /path/to/directory --full-path
  tree -- -directory
TEXT

for flag in -h '-?' --help; do
  NO_COLOR=1 "$dos2unix_bin" "$flag" >"$fixture/out" 2>"$fixture/err"
  [ ! -s "$fixture/err" ] || fail "dos2unix $flag wrote stderr"
  grep -q '^dos2unix v0\.1\.2$' "$fixture/out" || fail "dos2unix $flag version header"
  grep -q 'dos2unix \[options\] \[--\] FILE' "$fixture/out" || fail "dos2unix $flag usage"
  grep -q 'https://github.com/queone/skit' "$fixture/out" || fail "dos2unix $flag source URL"
  cmp "$fixture/out" "$fixture/dos2unix-help" || fail "dos2unix $flag exact help"

  NO_COLOR=1 "$tree_bin" "$flag" >"$fixture/out" 2>"$fixture/err"
  [ ! -s "$fixture/err" ] || fail "tree $flag wrote stderr"
  grep -q '^tree v0\.1\.2$' "$fixture/out" || fail "tree $flag version header"
  grep -q 'tree \[options\] \[directory\]' "$fixture/out" || fail "tree $flag usage"
  grep -q 'https://github.com/queone/skit' "$fixture/out" || fail "tree $flag source URL"
  cmp "$fixture/out" "$fixture/tree-help" || fail "tree $flag exact help"
done

for flag in -v --version; do
  [ "$(NO_COLOR=1 "$dos2unix_bin" ignored "$flag" extra)" = 'dos2unix v0.1.2' ] ||
    fail "dos2unix $flag output"
  [ "$(NO_COLOR=1 "$tree_bin" ignored "$flag" extra)" = 'tree v0.1.2' ] ||
    fail "tree $flag output"
done

printf 'a\r\nb\nc\377' >"$fixture/input"
cp "$fixture/input" "$fixture/original"
NO_COLOR=1 "$dos2unix_bin" "$fixture/input" >"$fixture/out"
cmp "$fixture/input" "$fixture/original" || fail 'preview modified input'
printf 'a\\r\\n\nb\nc\377' >"$fixture/expected"
cmp "$fixture/out" "$fixture/expected" || fail 'preview bytes differ'
NO_COLOR=1 "$dos2unix_bin" "$fixture/input" --force >"$fixture/out"
[ ! -s "$fixture/out" ] || fail 'force wrote stdout'
printf 'a\nb\nc\377' >"$fixture/expected"
cmp "$fixture/input" "$fixture/expected" || fail 'force bytes differ'

mkdir "$fixture/root"
touch "$fixture/root/.hidden" "$fixture/root/alpha"
mkdir "$fixture/root/nested"
touch "$fixture/root/nested/z"
NO_COLOR=1 "$tree_bin" "$fixture/root" >"$fixture/out"
printf '├── .hidden\n├── alpha\n└── nested\n    └── z\n' >"$fixture/expected"
cmp "$fixture/out" "$fixture/expected" || fail 'tree output differs'

if [ "$(uname -s)" != MINGW* ]; then
  set +e
  NO_COLOR=1 "$dos2unix_bin" $'\200' >"$fixture/out" 2>"$fixture/err"
  status=$?
  set -e
  [ "$status" -eq 1 ] || fail 'dos2unix invalid UTF-8 exit code'
  [ ! -s "$fixture/out" ] || fail 'dos2unix invalid UTF-8 wrote stdout'
  grep -q 'not valid UTF-8.*retry' "$fixture/err" ||
    fail 'dos2unix invalid UTF-8 guidance'

  set +e
  NO_COLOR=1 "$tree_bin" $'\200' >"$fixture/out" 2>"$fixture/err"
  status=$?
  set -e
  [ "$status" -eq 1 ] || fail 'tree invalid UTF-8 exit code'
  [ ! -s "$fixture/out" ] || fail 'tree invalid UTF-8 wrote stdout'
  grep -q 'not valid UTF-8.*retry' "$fixture/err" ||
    fail 'tree invalid UTF-8 guidance'
fi
