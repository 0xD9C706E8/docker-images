#!/usr/bin/env bash
# Render the README image table from per-image metadata.
#
# Iterates images/<app>/image.yaml in alpha order, reads upstream/base/platforms
# from each, rewrites README.md between the marker pair:
#   <!-- image-table:start --> ... <!-- image-table:end -->
#
# Defaults when keys are missing or null:
#   description: (empty cell)
#   license:     (empty cell)
#   platforms:   linux/amd64, linux/arm64
#   upstream:    (empty cell)
#   base:        (empty cell)
#
# Image directories without an image.yaml are skipped silently. That keeps
# half-built or in-progress image dirs out of the published table.
#
# Exit codes:
#   0 - README already up to date.
#   1 - README was regenerated. pre-commit re-stages the file and blocks the
#       commit; CI's lint job re-runs the hook and fails.

set -euo pipefail

readme="${1:-README.md}"
start_marker='<!-- image-table:start -->'
end_marker='<!-- image-table:end -->'

if [ ! -f "$readme" ]; then
  echo "::error::$readme not found" >&2
  exit 1
fi

if ! grep --quiet --fixed-strings "$start_marker" "$readme"; then
  echo "::error file=${readme}::missing marker '${start_marker}'" >&2
  exit 1
fi
if ! grep --quiet --fixed-strings "$end_marker" "$readme"; then
  echo "::error file=${readme}::missing marker '${end_marker}'" >&2
  exit 1
fi

render_row() {
  local config="$1"
  local dir name upstream base description license platforms_raw arches link upstream_cell

  dir=$(dirname "$config")
  name=$(basename "$dir")
  upstream=$(yq --unwrapScalar '.upstream // ""' "$config")
  base=$(yq --unwrapScalar '.base // ""' "$config")
  description=$(yq --unwrapScalar '.description // ""' "$config")
  license=$(yq --unwrapScalar '.license // ""' "$config")
  platforms_raw=$(yq --unwrapScalar '(.platforms // ["linux/amd64", "linux/arm64"]) | join(",")' "$config")

  # Strip linux/ prefix from each platform; join with ", ".
  arches=$(printf '%s' "$platforms_raw" | tr ',' '\n' | sed 's|^linux/||' | tr '\n' ',' | sed 's/,$//')
  arches=${arches//,/, }

  link="[${name}](images/${name}/)"
  if [ -n "$upstream" ]; then
    # Display text = repo path for github URLs, hostname for the rest.
    local display
    case "$upstream" in
      https://github.com/*) display=${upstream#https://github.com/} ;;
      *) display=$(echo "$upstream" | sed -E 's|^https?://([^/]+).*|\1|') ;;
    esac
    upstream_cell="[${display}](${upstream})"
  else
    upstream_cell=""
  fi

  printf '| %s | %s | %s | %s | %s | %s |\n' "$link" "$upstream_cell" "$base" "$arches" "$description" "$license"
}

table_file=$(mktemp)
{
  printf '| Image | Upstream | Base | Arches | Description | License |\n'
  printf '| --- | --- | --- | --- | --- | --- |\n'
  find images -mindepth 2 -maxdepth 2 -name image.yaml -type f 2> /dev/null | sort | while read -r config; do
    render_row "$config"
  done
} > "$table_file"

# Replace the block between the markers with: marker, blank, table, blank, marker.
# awk reads the table from a file so the replacement can contain newlines.
tmp=$(mktemp)
awk -v start="$start_marker" -v end="$end_marker" -v table_file="$table_file" '
  $0 ~ start {
    print
    print ""
    print "<!-- prettier-ignore-start -->"
    print ""
    while ((getline line < table_file) > 0) print line
    close(table_file)
    print ""
    print "<!-- prettier-ignore-end -->"
    print ""
    in_block = 1
    next
  }
  $0 ~ end {
    in_block = 0
    print
    next
  }
  !in_block { print }
' "$readme" > "$tmp"

rm -f "$table_file"

if ! cmp --silent "$readme" "$tmp"; then
  mv "$tmp" "$readme"
  echo "::notice file=${readme}::image table regenerated"
  exit 1
else
  rm -f "$tmp"
fi
