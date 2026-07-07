#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

banner
header "Recent Jobs"

print_history_header

tail -n +2 "$HISTORY_FILE" | tac |
while IFS=$'\t' read \
    JOBID SUBMIT JOBNAME NODE CPUS MEM WORKDIR SCRIPT LOGFILE
do


    sync_job_metadata "$JOBID" "$NODE"

    table_history_row \
        "$JOBID" \
        "$JOBNAME" \
        "$NODE" \
        "$CPUS" \
        "$MEM" \
        "$(job_runtime "$JOBID")" \
        "$(format_submit_time "$SUBMIT")" \
        "$(job_status "$JOBID")"

done

