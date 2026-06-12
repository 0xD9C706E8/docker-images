#!/usr/bin/env bash
set -euo pipefail

file="${1:?Dockerfile path required}"

if [ ! -f "$file" ]; then
  echo "::notice file=${file}::Dockerfile does not exist; skipping"
  exit 0
fi

awk '
BEGIN { rc = 0 }

function fail(msg) {
    printf "::error file=%s,line=%d::%s\n", FILENAME, NR, msg
    rc = 1
}

/^[[:space:]]*#[[:space:]]*renovate:/ {
    if (match($0, /datasource=[^[:space:]]+/)) {
        ann_ds = substr($0, RSTART + 11, RLENGTH - 11)
    } else {
        ann_ds = ""
    }
    if (match($0, /depName=[^[:space:]]+/)) {
        ann_dep = substr($0, RSTART + 8, RLENGTH - 8)
    } else {
        ann_dep = ""
    }
    if (ann_ds == "") {
        fail("renovate annotation missing datasource=")
    }
    if (ann_dep == "") {
        fail("renovate annotation missing depName=")
    }
    if (has_ann && !ann_consumed) {
        fail("consecutive # renovate: annotations before single ARG *_VERSION=")
    }
    has_ann = 1
    ann_consumed = 0
    next
}

# Blank line: an annotation followed by a blank line and only THEN by ARG *_VERSION=
# is technically tolerated by the generic manager but we keep things uniform.
/^[[:space:]]*$/ {
    if (has_ann && !ann_consumed) {
        fail("blank line between # renovate: annotation and ARG *_VERSION=")
        has_ann = 0
    }
    next
}

/^[[:space:]]*ARG[[:space:]]+[A-Za-z_][A-Za-z0-9_]*_VERSION=/ {
    if (!has_ann) {
        fail("ARG *_VERSION= without preceding # renovate: annotation")
    } else {
        ann_consumed = 1
        has_ann = 0
    }
    next
}

# Any other line: an annotation that was followed by something that is
# NOT an ARG *_VERSION= is a dangling annotation Renovate cannot match.
{
    if (has_ann && !ann_consumed) {
        fail("# renovate: annotation not followed by ARG *_VERSION= on the next non-blank line")
        has_ann = 0
    }
}

END {
    if (has_ann && !ann_consumed) {
        fail("# renovate: annotation at end of file with no following ARG *_VERSION=")
    }
    exit rc
}
' "$file"
