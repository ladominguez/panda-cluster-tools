#!/bin/bash

set -e

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate ai

HOST=$(hostname)

{
echo "Host: $HOST"
echo "Start: $(date)"

time python book2.py

echo "End: $(date)"
} > "${HOST}.log" 2>&1
