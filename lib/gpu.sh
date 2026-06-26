#!/bin/bash
#
# gpu.sh
#
# Display GPU status for the Panda Cluster
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

############################################################
# Dependencies
############################################################

require_command nvidia-smi

############################################################
# Banner
############################################################

banner
header "GPU Status"

############################################################
# Loop over nodes
############################################################

for node in "${NODES[@]}"
do

    echo
    echo "============================================================"
    echo "$node"
    echo "============================================================"

    ########################################################
    # Is node reachable?
    ########################################################

    if ! check_node "$node"
    then
        warning "Node is offline."
        continue
    fi

    ########################################################
    # Query GPUs
    ########################################################

    gpu=0

    node_exec "$node" \
        nvidia-smi \
        --query-gpu=name,memory.used,memory.total,utilization.gpu,temperature.gpu,power.draw \
        --format=csv,noheader,nounits |

    while IFS=',' read NAME USED TOTAL UTIL TEMP POWER
    do

        NAME=$(echo "$NAME" | xargs)
        USED=$(echo "$USED" | xargs)
        TOTAL=$(echo "$TOTAL" | xargs)
        UTIL=$(echo "$UTIL" | xargs)
        TEMP=$(echo "$TEMP" | xargs)
        POWER=$(echo "$POWER" | xargs)

        echo
        echo "GPU $gpu : $NAME"
        echo

        printf "Memory "
        progress_bar "$USED" "$TOTAL" 30
        printf " %6s / %-6s MB\n" "$USED" "$TOTAL"

        printf "GPU    "
        progress_bar "$UTIL" 100 30
        printf " %3s %%\n" "$UTIL"

        printf "Temp   %3s °C\n" "$TEMP"
        printf "Power  %5.1f W\n" "$POWER"

        ((gpu++))

    done

done

echo
