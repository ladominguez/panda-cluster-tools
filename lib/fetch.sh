#!/bin/bash

source "$(dirname "$0")/common.sh"

JOBID="$1"
JOBFILE="$JOB_DIR/${JOBID}.conf"

if [[ ! -f "$JOBFILE" ]]; then
    echo "Error: Job metadata not found: $JOBFILE"
    exit 1
fi

source "$JOBFILE"

mkdir -p "$HOME/clusterlogs/Logs"

scp "$NODE:$LOGFILE" "$HOME/clusterlogs/Logs/"



