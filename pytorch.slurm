#!/bin/bash

#SBATCH --job-name=train
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --output=~/clusterlogs/Logs/%x-%j.out

set -e

##########################################################
# Environment
##########################################################

source ~/miniconda3/etc/profile.d/conda.sh
conda activate torch-py312

##########################################################
# Information
##########################################################

echo "=============================================="
echo "Job ID        : $SLURM_JOB_ID"
echo "Job Name      : $SLURM_JOB_NAME"
echo "Node          : $(hostname)"
echo "User          : $(whoami)"
echo "Date          : $(date)"
echo "Working Dir   : $(pwd)"
echo "GPU           : $CUDA_VISIBLE_DEVICES"
echo "=============================================="

python --version

python - <<EOF
import torch

print()
print("Torch:",torch.__version__)
print("CUDA:",torch.version.cuda)
print("Device:",torch.cuda.get_device_name(0))
print()
EOF

##########################################################
# YOUR PROGRAM
##########################################################

python train.py

##########################################################
# Finished
##########################################################

echo
echo "Finished at $(date)"
