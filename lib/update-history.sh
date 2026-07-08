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
    $3=finish
    $4=status
    $5=exitcode
    $6=runtime
}

{
    print
}
' "$HISTORY_FILE" > "$TMP"

mv "$TMP" "$HISTORY_FILE"
