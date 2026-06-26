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
