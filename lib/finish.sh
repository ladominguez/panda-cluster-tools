#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

JOBID="$1"
EXITCODE="$2"
ELAPSED="$3"

STATUS="FAILED"

if [[ "$EXITCODE" -eq 0 ]]; then
    STATUS="COMPLETED"
fi

if [[ "$(hostname -s)" == "$CONTROLLER" ]]; then
    "$PANDA_HOME/bin/panda" update-history \
        "$JOBID" \
        "$STATUS" \
        "$EXITCODE" \
        "$ELAPSED"
else
    ssh "${SSH_OPTS[@]}" "$CONTROLLER" \
        "$PANDA_HOME/bin/panda update-history \
            '$JOBID' \
            '$STATUS' \
            '$EXITCODE' \
            '$ELAPSED'"
fi



