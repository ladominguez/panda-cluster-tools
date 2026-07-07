#!/bin/bash
#
# common.sh
#
# Common library for Panda Cluster
#

############################################################
# Locate project directories
############################################################


COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PANDA_HOME="$(cd "$COMMON_DIR/.." && pwd)"

PANDA_VAR="$PANDA_HOME/var"
JOB_DIR="$PANDA_VAR/jobs"
HISTORY_FILE="$PANDA_VAR/history.tsv"

mkdir -p "$JOB_DIR"

if [[ ! -f "$HISTORY_FILE" ]]; then
    printf "JobID\tSubmitTime\tJobName\tNode\tCPUs\tMem\tWorkDir\tScript\tLogFile\n" \
        > "$HISTORY_FILE"
fi

PROJECT_ROOT="$(cd "$COMMON_DIR/.." && pwd)"
CONFIG_DIR="$PROJECT_ROOT/config"
LOCAL_NODE=$(hostname -s)

############################################################
# Load configuration
############################################################

CONFIG_FILE="$CONFIG_DIR/cluster.conf"

[[ -f "$CONFIG_FILE" ]] \
    || { echo "Cannot find $CONFIG_FILE"; exit 1; }

source "$CONFIG_FILE"

############################################################
# Panda database
############################################################

PANDA_VAR="$PANDA_HOME/var"

mkdir -p "$PANDA_VAR/jobs"

HISTORY_FILE="$PANDA_VAR/history.tsv"


############################################################
# User configuration
############################################################

USER_CONFIG="$HOME/.panda.conf"

if [[ -f "$USER_CONFIG" ]]
then
    source "$USER_CONFIG"
fi


############################################################
# SSH
############################################################

SSH_OPTS=(
    -o BatchMode=yes
    -o ConnectTimeout="${SSH_TIMEOUT}"
    -o StrictHostKeyChecking=accept-new
)

############################################################
# Colors
############################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

############################################################
# Logging
############################################################

LOGFILE="$HOME/.cluster-tools.log"

############################################################
# Pretty printing
############################################################

header()
{
    echo
    echo -e "${BOLD}${CYAN}============================================================${RESET}"
    echo -e "${BOLD}${CYAN}$*${RESET}"
    echo -e "${BOLD}${CYAN}============================================================${RESET}"
}

info()
{
    echo -e "${BLUE}[INFO]${RESET} $*"
}

success()
{
    echo -e "${GREEN}[ OK ]${RESET} $*"
}

warning()
{
    echo -e "${YELLOW}[WARN]${RESET} $*"
}

failure()
{
    echo -e "${RED}[FAIL]${RESET} $*"
}

die()
{
    failure "$*"
    exit 1
}


############################################################
# Logging
############################################################

timestamp()
{
    date "+%Y-%m-%d %H:%M:%S"
}

log()
{
    echo "$(timestamp) $*" >> "$LOGFILE"
}

############################################################
# Dependencies
############################################################

require_command()
{
    command -v "$1" >/dev/null 2>&1 \
        || die "Required command '$1' is not installed."
}

############################################################
# Execute on a node
############################################################

node_exec()
{
    
    local node="$1"
    shift

    if [[ "$node" == "$LOCAL_NODE" ]]
    then
        "$@"
    else
        ssh "${SSH_OPTS[@]}" "$node" "$@"
    fi
}

############################################################
# Copy file
############################################################

node_copy()
{
    local src="$1"
    local node="$2"
    local dst="$3"

    if [[ "$node" == "$LOCAL_NODE" ]]
    then
        cp "$src" "$dst"
    else
        scp -q "$src" "$node:$dst"
    fi
}

############################################################
# Node helpers
############################################################

check_node()
{
    local node="$1"

    ping -c1 -W1 "$node" >/dev/null 2>&1
}

############################################################
# Slurm
############################################################

slurm_running()
{
    scontrol ping >/dev/null 2>&1
}

restart_slurmd()
{
    local node="$1"

    node_exec "$node" sudo systemctl restart slurmd
}

restart_slurmctld()
{
    node_exec "$CONTROLLER" sudo systemctl restart slurmctld
}


############################################################
# Wait until all nodes are ready
############################################################

wait_cluster()
{
    local timeout=30
    local elapsed=0

    GOOD_STATES="idle|mixed|alloc"

    while (( elapsed < timeout ))
    do

        local bad

        bad=$(sinfo -h -o "%T" | grep -vcE "GOOD_STATES")

        [[ "$bad" -eq 0 ]] && return 0

        sleep 1
        ((elapsed++))

    done

    return 1
}


############################################################
# Compare local/remote files
############################################################

same_file()
{
    local localfile="$1"
    local node="$2"
    local remotefile="$3"

    local local_md5
    local remote_md5

    local_md5=$(md5sum "$localfile" | awk '{print $1}')

    remote_md5=$(
        node_exec "$node" \
            md5sum "$remotefile" 2>/dev/null \
            | awk '{print $1}'
    )

    [[ "$local_md5" == "$remote_md5" ]]
}

############################################################
# Panda Cluster banner
############################################################

banner()
{
    echo
    echo "🐼  $CLUSTER_NAME    v$CLUSTER_VERSION"
    echo "    Powered by pandas."
    echo
}

############################################################
# Execute on every node
############################################################

for_each_node()
{
    local cmd=("$@")

    for node in "${NODES[@]}"
    do
        "${cmd[@]}" "$node"
    done
}


############################################################
# Progress bar
############################################################

progress_bar()
{
    local current="$1"
    local total="$2"
    local width="${3:-30}"

    (( total == 0 )) && total=1

    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))

    printf "["

    printf "%${filled}s" "" | tr ' ' '█'
    printf "%${empty}s" "" | tr ' ' '░'

    printf "]"
}


print_history_header()
{
    printf "%-5s %-18s %-12s %5s %6s %10s %18s %12s\n" \
        "ID" \
        "Name" \
        "Node" \
        "CPUs" \
        "Mem" \
        "Runtime" \
        "Submitted" \
        "Status"

    printf '%*s\n' 95 '' | tr ' ' '-'
}


table_history_row()
{
    local JOBID="$1"
    local NAME="$2"
    local NODE="$3"
    local CPUS="$4"
    local MEM="$5"
    local RUNTIME="$6"
    local SUBMITTED="$7"
    local STATUS="$8"

    printf "%-5s %-18s %-12s %5s %6s %10s %18s %12s\n" \
        "$JOBID" \
        "$NAME" \
        "$NODE" \
        "$CPUS" \
        "$MEM" \
        "$RUNTIME" \
        "$SUBMITTED" \
        "$STATUS"
}


format_submit_time()
{
  date -d "$1" '+%H:%M'
}


job_status()
{
    local JOBID="$1"
    local JOBFILE="$JOB_DIR/${JOBID}.conf"

    #----------------------------------------------------------
    # Is the job still in Slurm?
    #----------------------------------------------------------

    local STATE

    STATE=$(squeue -h -j "$JOBID" -O State 2>/dev/null)

    case "$STATE" in
        RUNNING)
            echo "⏳ Running"
            return
            ;;

        PENDING)
            echo "⏸ Pending"
            return
            ;;

        CONFIGURING)
            echo "⚙ Configuring"
            return
            ;;

        COMPLETING)
            echo "⏹ Completing"
            return
            ;;
    esac

    #----------------------------------------------------------
    # Job no longer in Slurm
    # Check Panda database
    #----------------------------------------------------------



    if [[ -f "$JOBFILE" ]]; then
    unset STATUS EXITCODE RUNTIME FINISHED

    if ! source "$JOBFILE"; then
        echo "?"
        return
    fi

    case "$STATUS" in
        COMPLETED) echo "✓ Done" ;;
        FAILED)    echo "✗ Failed" ;;
        CANCELLED) echo "⊘ Cancelled" ;;
        *)         echo "--" ;;
    esac
    fi
}


job_runtime()
{
    local JOBID="$1"

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/common.sh"

    JOBFILE="$JOB_DIR/${JOBID}.conf"

    #
    # Is the job still running?
    #
    local RT

    RT=$(squeue -h -j "$JOBID" -O TimeUsed 2>/dev/null)

    if [[ -n "$RT" ]]; then
        echo "$RT"
        return
    fi

    #
    # Finished job
    #
    if [[ -f "$JOBFILE" ]]; then

        unset RUNTIME

        source "$JOBFILE" >/dev/null 2>&1

	if [[ -n "$RUNTIME" ]]; then
              format_seconds "$RUNTIME"
              return
        fi

    fi

    echo "--"
}

format_seconds()
{
    local SEC="$1"

    printf "%02d:%02d:%02d\n" \
        $((SEC/3600)) \
        $(((SEC%3600)/60)) \
        $((SEC%60))
}

translate_path()
{
    local path="$1"
    local node="$2"

    local local_root="${PATH_MAP[$LOCAL_NODE]}"
    local remote_root="${PATH_MAP[$node]}"

    if [[ -n "$local_root" && -n "$remote_root" ]]; then
        echo "${path/$local_root/$remote_root}"
    else
        echo "$path"
    fi
}

sync_job_metadata()
{
    local JOBID="$1"
    local NODE="$2"

    #
    # Local node? Nothing to do.
    #
    [[ "$NODE" == "$LOCAL_NODE" ]] && return

    local REMOTE_VAR
    REMOTE_VAR=$(translate_path "$PANDA_VAR" "$NODE")

    rsync -a \
        "$NODE:$REMOTE_VAR/jobs/${JOBID}.conf" \
        "$PANDA_VAR/jobs/" \
        >/dev/null 2>&1
}


