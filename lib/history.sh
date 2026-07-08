#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

banner
header "Recent Jobs"

print_history_header


tail -n +2 "$HISTORY_FILE" | tac |
while IFS=$'\t' read -r \
    JOBID \
    SUBMIT \
    FINISH \
    STATUS \
    EXITCODE \
    RUNTIME \
    JOBNAME \
    NODE \
    CPUS \
    MEM \
    WORKDIR \
    SCRIPT \
    LOGFILE
do
    table_history_row \
        "$JOBID" \
        "$JOBNAME" \
        "$NODE" \
        "$CPUS" \
        "$MEM" \
        "$RUNTIME" \
        "$(format_submit_time "$SUBMIT")" \
        "$STATUS"
done




