#!/usr/bin/env bash
# Decide which images to (re)build for the current GitHub Actions event.
#
# Outputs are written to $GITHUB_OUTPUT and $GITHUB_STEP_SUMMARY as:
#   images=<json array of image directory names, possibly empty>
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

# Filter a newline-separated list of changed paths down to the unique image
# directory names found under images/, returned as a JSON array. Returns []
# when no paths match. Tolerates grep's exit-1-on-no-match under set -e.
image_dirs_from_changes() {
  local changed="$1"
  local matches
  matches=$(echo "$changed" | grep --only-matching --perl-regexp 'images/\K[^/]+' | sort --unique || true)
  if [ -z "$matches" ]; then
    echo '[]'
  else
    echo "$matches" | jq --raw-input --compact-output '[., inputs]'
  fi
}

# Build a regex that matches any of the rebuild-all trigger paths.
# Comma-separated input -> alternation, with dots escaped.
trigger_regex=$(echo "$rebuild_all_triggers" | tr ',' '\n' | sed 's/[.]/\\./g' | paste --serial --delimiters='|' -)

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

if [ "$images" = "[]" ]; then
  has_changes=false
else
  has_changes=true
fi

{
  echo "images=${images}"
  echo "has-changes=${has_changes}"
} >> "$GITHUB_OUTPUT"

{
  echo "### Detected images"
  echo
  echo '```json'
  echo "$images"
  echo '```'
} >> "$GITHUB_STEP_SUMMARY"
