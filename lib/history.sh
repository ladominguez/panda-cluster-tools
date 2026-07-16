#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

banner
header "Recent Jobs"

DEFAULT_NUM=20
SHOW_ALL=false
NUM=$DEFAULT_NUM

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--num)
            NUM="$2"
            shift 2
            ;;
        --all)
            SHOW_ALL=true
            shift
            ;;
        *)
            echo "Usage: panda history [-n N] [--all]"
            exit 1
            ;;
    esac
done

if ! [[ "$NUM" =~ ^[0-9]+$ ]]; then
    echo "Error: -n requires a positive integer."
    exit 1
fi

print_history_header

if $SHOW_ALL; then
    tail -n +2 "$HISTORY_FILE" | tac
else
    tail -n +2 "$HISTORY_FILE" | tail -n "$NUM" | tac
fi |

while IFS=$'\t' read -r \
    JOBID \
    USER_NAME \
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
	"$USER_NAME" \
        "$JOBNAME" \
        "$NODE" \
        "$CPUS" \
        "$MEM" \
	"$(format_seconds "$RUNTIME")" \
        "$(format_submit_time "$SUBMIT")" \
        "$STATUS"
done




