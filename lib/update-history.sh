#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

JOBID="$1"
STATUS="$2"
EXITCODE="$3"
RUNTIME="$4"

# Never leave empty fields in history.tsv
[[ -z "$EXITCODE" ]] && EXITCODE="-"
[[ -z "$RUNTIME"  ]] && RUNTIME="-"

FINISH_TIME=$(date '+%Y-%m-%dT%H:%M:%S')

TMP=$(mktemp)

trap 'rm -f "$TMP"' EXIT

awk -F'\t' -v OFS='\t' \
    -v jobid="$JOBID" \
    -v finish="$FINISH_TIME" \
    -v status="$STATUS" \
    -v exitcode="$EXITCODE" \
    -v runtime="$RUNTIME" '
NR==1 {
    print
    next
}

$1==jobid {
    $4=finish
    $5=status
    $6=exitcode
    $7=runtime
}

{
    print
}
' "$HISTORY_FILE" > "$TMP"



if mv "$TMP" "$HISTORY_FILE"; then
    trap - EXIT
else
    echo "Failed to update history file." >&2
    exit 1
fi
