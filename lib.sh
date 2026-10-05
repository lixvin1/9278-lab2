#!/bin/bash
# Shared code used by the antivirus scripts.
# This file is meant to be loaded with source.

BAD_EXTENSIONS=(.exe .bat .vbs .scr .ps1)
BAD_KEYWORDS=(virus trojan malware worm ransomware)

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${AV_STATE_DIR:-$LIB_DIR}"

LAST="$STATE_DIR/directory-info.last"
NEW="$STATE_DIR/directory-info.new"
WHITELIST="$STATE_DIR/whitelist.txt"

# Return 0 when the file name has a required bad extension.
has_bad_extension() {
  local name=$1 ext bad
  [[ $name == *.* ]] || return 1
  ext=".${name##*.}"
  for bad in "${BAD_EXTENSIONS[@]}"; do
    [[ $ext == "$bad" ]] && return 0
  done
  return 1
}

# Return 0 when the file contains one of the required keywords.
# The search is case-insensitive.
has_bad_keyword() {
  printf '%s\n' "${BAD_KEYWORDS[@]}" | grep -qiF -f - -- "$1" 2>/dev/null
}

# A file is malicious when either rule matches.
is_malicious() {
  has_bad_extension "$(basename -- "$1")" || has_bad_keyword "$1"
}

# Store both the SHA-256 and file name in the whitelist.
# This means both the content and the name must match later.
file_hash() {
  sha256sum < "$1" | cut -d' ' -f1
}

is_whitelisted() {
  local h n
  [ -f "$WHITELIST" ] || return 1
  h=$(file_hash "$1") || return 1
  n=$(basename -- "$1")
  grep -Fqsx -- "$h $n" "$WHITELIST"
}

whitelist_add() {
  local h n
  h=$(file_hash "$1") || return 1
  n=$(basename -- "$1")
  is_whitelisted "$1" && return 0
  printf '%s %s\n' "$h" "$n" >> "$WHITELIST"
}

# Copy first. Only say "DELETED" after the original was really removed.
quarantine() {
  local file=$1 mal=$2

  if ! cp -- "$file" "$mal/"; then
    echo "Error: could not quarantine '$file'." >&2
    return 1
  fi

  if ! rm -- "$file"; then
    echo "Error: quarantined '$file', but could not delete the original." >&2
    return 1
  fi

  echo "$file is malicious and it is DELETED"
  return 0
}

scan_directory() {
  local dir=$1 mal=$2 file

  for file in "$dir"/*; do
    [ -f "$file" ] || continue

    if is_malicious "$file" && ! is_whitelisted "$file"; then
      quarantine "$file" "$mal"
    fi
  done
}

snapshot() {
  ls -l -- "$1" > "$2"
}

check_and_scan() {
  local dir=$1 mal=$2

  # First run: scan immediately, then save the first snapshot.
  if [ ! -f "$LAST" ]; then
    scan_directory "$dir" "$mal" || return 1
    snapshot "$dir" "$LAST" || return 1
    return 0
  fi

  snapshot "$dir" "$NEW" || return 1

  if ! cmp -s "$LAST" "$NEW"; then
    scan_directory "$dir" "$mal" || return 1

    # Scanning can remove files, so refresh the snapshot after the scan.
    snapshot "$dir" "$NEW" || return 1
    cp -- "$NEW" "$LAST" || return 1
  fi

  return 0
}
