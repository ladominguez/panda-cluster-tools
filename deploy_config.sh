#!/bin/bash

set -e

SLURM_DIR=/usr/local/slurm/etc
NODES=("shuanshuan" "tohui" "xinxin")

echo
echo "Deploying Slurm configuration..."
echo

for node in "${NODES[@]}"
do
    echo "===== $node ====="

    scp slurm.conf $node:/tmp/
    scp cgroup.conf $node:/tmp/
    scp gres/${node}.conf $node:/tmp/gres.conf

    ssh $node <<EOF
sudo cp /tmp/slurm.conf $SLURM_DIR/
sudo cp /tmp/cgroup.conf $SLURM_DIR/
sudo cp /tmp/gres.conf $SLURM_DIR/gres.conf

sudo systemctl restart slurmd
EOF

done

echo
echo "Done."

echo
echo "Cluster status"

sinfo -N -l
