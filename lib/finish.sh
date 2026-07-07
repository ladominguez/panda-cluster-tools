#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

JOBID="$1"
EXITCODE="$2"
ELAPSED="$3"

JOBFILE="$PANDA_VAR/jobs/${JOBID}.conf"

{
    echo "EXITCODE=$EXITCODE"
    echo "RUNTIME=$ELAPSED"
    echo "FINISHED=$(date '+%Y-%m-%dT%H:%M:%S')"

    if [[ "$EXITCODE" -eq 0 ]]; then
        echo "STATUS=COMPLETED"
    else
        echo "STATUS=FAILED"
    fi
} >> "$JOBFILE"
