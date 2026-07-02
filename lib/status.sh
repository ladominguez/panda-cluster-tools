#!/bin/bash
#
# status.sh
#
# Display the current status of the Panda Cluster
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

############################################################
# Dependencies
############################################################

require_command sinfo
require_command squeue
require_command scontrol
require_command ssh

############################################################
# Banner
############################################################

banner

############################################################
# Controller
############################################################

header "Controller"

if slurm_running
then
    success "Slurm controller is running."
else
    die "Slurm controller is not responding."
fi

############################################################
# Nodes
############################################################

header "Nodes"

printf "%-12s %-10s %-5s %-8s %-10s\n" \
    "Node" "State" "CPU" "Memory" "GPU"

printf "%-12s %-10s %-5s %-8s %-10s\n" \
    "------------" "----------" "-----" "--------" "----------"


while IFS= read -r node
do
    scontrol show node "$node" | awk '
        /State=/ {
            match($0,/State=([^ ]+)/,a)
            split(a[1],b,"+")
            state=b[1]
        }
        /CPUTot=/ {
            match($0,/CPUTot=([0-9]+)/,a)
            cpu=a[1]
        }
        /RealMemory=/ {
            match($0,/RealMemory=([0-9]+)/,a)
            mem=a[1]
        }
        /Gres=/ {
            match($0,/Gres=([^ ]+)/,a)
            gpu=a[1]
        }
        END {
            printf "%-12s %-10s %-5s %-8s %-10s\n", "'"$node"'", state, cpu, mem "M", gpu
        }
    '
done < <(printf "%s\n" "${NODES[@]}")



############################################################
# Jobs
############################################################

header "Jobs"

if [[ $(squeue -h | wc -l) -eq 0 ]]
then
    info "No running jobs."
else

    squeue \
        -o "%.8i %.12j %.10u %.10T %.10M %.12R"

fi

############################################################
# GPU Status
############################################################

header "GPU Status"

for node in "${NODES[@]}"
do

    echo
    echo "$node"

    if ! check_node "$node"
    then
        warning "Node unreachable."
        continue
    fi

    node_exec "$node" \
        nvidia-smi \
        --query-gpu=name,memory.used,memory.total,utilization.gpu \
        --format=csv,noheader

done

############################################################
# Disk usage
############################################################

header "Disk Usage"

printf "%-12s %s\n" "Node" "Filesystem"

for node in "${NODES[@]}"
do

    printf "%-12s " "$node"

    node_exec "$node" \
        df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}'

done

############################################################
# Summary
############################################################

header "Summary"

echo "Cluster     : $CLUSTER_NAME"
echo "Controller  : $CONTROLLER"
echo "Nodes       : ${#NODES[@]}"
echo "Jobs        : $(squeue -h | wc -l)"
echo "Timestamp   : $(timestamp)"
