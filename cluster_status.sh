#!/bin/bash

echo
echo "========================="
echo " Nodes"
echo "========================="

sinfo -N -o "%-12N %-10T %8c %8m %G"

echo
echo "========================="
echo " GPUs"
echo "========================="

HOST=$(hostname -s)

for node in shuanshuan tohui xinxin
do
    echo
    echo "----- $node -----"

    if [[ "$node" == "$HOST" ]]; then
        nvidia-smi \
            --query-gpu=name,memory.used,memory.total,utilization.gpu \
            --format=csv,noheader
    else
        ssh "$node" \
            nvidia-smi \
            --query-gpu=name,memory.used,memory.total,utilization.gpu \
            --format=csv,noheader
    fi
done
