#!/usr/bin/env bash
# Decide which images to (re)build for the current GitHub Actions event.
#
# Outputs are written to $GITHUB_OUTPUT and $GITHUB_STEP_SUMMARY as:
#   images=<json array of image directory names, possibly empty>
#   include=<json array of {image, platform} pairs, possibly empty>
#   has-changes=<true|false>
#
# Inputs:
#   $1: comma-separated list of workflow files that should fan out to all
#       images when changed. PR caller passes both workflow files; push
#       caller passes only build.yaml because ci.yaml changes do not affect
#       published artifacts.
#
# Required environment:
#   GITHUB_EVENT_NAME, GITHUB_OUTPUT, GITHUB_STEP_SUMMARY.
#   For pull_request events: GITHUB_BASE_REF.
#   For push events: GITHUB_EVENT_BEFORE, GITHUB_SHA.
#   For workflow_dispatch: optional WORKFLOW_DISPATCH_IMAGE input.

set -euo pipefail

rebuild_all_triggers="${1:?rebuild-all triggers (comma-separated workflow paths) required}"

list_all_images() {
  if [ -d images ] && [ -n "$(ls --almost-all images 2> /dev/null)" ]; then
    find images -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | jq --raw-input --compact-output '[., inputs]'
  else
    echo '[]'
  fi
}

# Expand a JSON array of image names into a {image, platform} pair per
# entry in each image's image.yaml platforms field. Default platforms are
# linux/amd64 + linux/arm64 when image.yaml is missing or omits the field.
expand_with_platforms() {
  local images_json="$1"
  local image platforms_json
  echo "$images_json" | jq --raw-output '.[]' | while IFS= read -r image; do
    config="images/${image}/image.yaml"
    if [ -f "$config" ]; then
      platforms_json=$(yq --output-format=json --indent=0 '.platforms // ["linux/amd64", "linux/arm64"]' "$config")
    else
      platforms_json='["linux/amd64", "linux/arm64"]'
    fi
    jq --compact-output --null-input --arg image "$image" --argjson platforms "$platforms_json" \
      '$platforms[] | {image: $image, platform: .}'
  done | jq --compact-output --slurp '.'
}

# Filter a newline-separated list of changed paths down to the unique image
# directory names found under images/, returned as a JSON array. Returns []
# when no paths match. Tolerates grep's exit-1-on-no-match under set -e.
image_dirs_from_changes() {
  local changed="$1"
  local matches
  matches=$(echo "$changed" | grep --only-matching --perl-regexp 'images/\K[^/]+' | sort --unique || true)
  if [ -z "$matches" ]; then
    echo '[]'
    return
  fi
  echo "$matches" | while IFS= read -r img; do
    [ -d "images/${img}" ] && echo "$img"
  done | jq --raw-input --compact-output '[., inputs]'
}

# Build a regex that matches any of the rebuild-all trigger paths.
# Comma-separated input -> alternation, with dots escaped.
trigger_regex=$(echo "$rebuild_all_triggers" | tr ',' '\n' | sed 's/[.]/\\./g' | paste -sd '|' -)

case "$GITHUB_EVENT_NAME" in
  schedule)
    images=$(list_all_images)
    ;;
  workflow_dispatch)
    if [ -n "${WORKFLOW_DISPATCH_IMAGE:-}" ]; then
      if [ ! -d "images/${WORKFLOW_DISPATCH_IMAGE}" ]; then
        echo "::error::workflow_dispatch input image='${WORKFLOW_DISPATCH_IMAGE}' has no directory at images/${WORKFLOW_DISPATCH_IMAGE}"
        exit 1
      fi
      images=$(jq --raw-input --compact-output '[.]' <<< "$WORKFLOW_DISPATCH_IMAGE")
    else
      images=$(list_all_images)
    fi
    ;;
  pull_request)
    changed=$(git diff --name-only "origin/${GITHUB_BASE_REF}...HEAD")
    if echo "$changed" | grep --quiet --extended-regexp "^(${trigger_regex})$"; then
      images=$(list_all_images)
    else
      images=$(image_dirs_from_changes "$changed")
    fi
    ;;
  push)
    before="${GITHUB_EVENT_BEFORE:-}"
    # Zero SHA appears on first push to a new branch; treat as "rebuild all".
    if [ -z "$before" ] || [ "$before" = "0000000000000000000000000000000000000000" ]; then
      images=$(list_all_images)
    else
      changed=$(git diff --name-only "${before}..${GITHUB_SHA}")
      if echo "$changed" | grep --quiet --extended-regexp "^(${trigger_regex})$"; then
        images=$(list_all_images)
      else
        images=$(image_dirs_from_changes "$changed")
      fi
    fi
    ;;
esac

include=$(expand_with_platforms "$images")
if [ "$include" = "[]" ]; then
  has_changes=false
else
  has_changes=true
fi

{
  echo "images=${images}"
  echo "include=${include}"
  echo "has-changes=${has_changes}"
} >> "$GITHUB_OUTPUT"

{
  echo "### Detected build matrix"
  echo
  echo '```json'
  echo "$include"
  echo '```'
} >> "$GITHUB_STEP_SUMMARY"
