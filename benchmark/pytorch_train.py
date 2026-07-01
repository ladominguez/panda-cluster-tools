#!/usr/bin/env python3
"""
Panda Cluster Benchmark

PyTorch training benchmark for validating GPU, CUDA,
Slurm and PyTorch installations.

Author:
    Luis Antonio Dominguez
    Instituto de Geofísica, UNAM
"""

import argparse
import platform
import socket
import sys
import time

import torch
import torch.nn as nn
import torch.optim as optim


# ------------------------------------------------------------
# Command-line arguments
# ------------------------------------------------------------

parser = argparse.ArgumentParser(
    description="PyTorch training benchmark"
)

parser.add_argument(
    "--epochs",
    type=int,
    default=50,
    help="Number of training epochs"
)

parser.add_argument(
    "--batch-size",
    type=int,
    default=2048,
    help="Batch size"
)

parser.add_argument(
    "--input-size",
    type=int,
    default=1024,
    help="Input dimension"
)

parser.add_argument(
    "--hidden-size",
    type=int,
    default=2048,
    help="Hidden layer size"
)

parser.add_argument(
    "--classes",
    type=int,
    default=100,
    help="Number of output classes"
)

parser.add_argument(
    "--learning-rate",
    type=float,
    default=1e-3,
    help="Learning rate"
)

parser.add_argument(
    "--seed",
    type=int,
    default=42,
    help="Random seed"
)

args = parser.parse_args()

torch.manual_seed(args.seed)

# ------------------------------------------------------------
# System information
# ------------------------------------------------------------

print("=" * 70)
print("PANDA CLUSTER PYTORCH BENCHMARK")
print("=" * 70)

print(f"Hostname          : {socket.gethostname()}")
print(f"Platform          : {platform.platform()}")
print(f"Python            : {platform.python_version()}")
print(f"PyTorch           : {torch.__version__}")
print(f"CUDA Available    : {torch.cuda.is_available()}")
print(f"CUDA Version      : {torch.version.cuda}")

if not torch.cuda.is_available():
    print("\nERROR: CUDA is not available.")
    sys.exit(1)

device = torch.device("cuda")

gpu_name = torch.cuda.get_device_name(0)
props = torch.cuda.get_device_properties(0)

print(f"GPU               : {gpu_name}")
print(f"Compute Capability: {props.major}.{props.minor}")
print(f"GPU Memory        : {props.total_memory / 1024**3:.2f} GB")

print("=" * 70)
print()

# ------------------------------------------------------------
# Model
# ------------------------------------------------------------

model = nn.Sequential(

    nn.Linear(args.input_size, args.hidden_size),
    nn.ReLU(),

    nn.Linear(args.hidden_size, args.hidden_size),
    nn.ReLU(),

    nn.Linear(args.hidden_size, args.hidden_size),
    nn.ReLU(),

    nn.Linear(args.hidden_size, args.classes),

).to(device)

criterion = nn.CrossEntropyLoss()

optimizer = optim.Adam(
    model.parameters(),
    lr=args.learning_rate
)

# ------------------------------------------------------------
# Dataset
# ------------------------------------------------------------

print("Creating synthetic dataset...")

x = torch.randn(
    args.batch_size,
    args.input_size,
    device=device
)

y = torch.randint(
    0,
    args.classes,
    (args.batch_size,),
    device=device
)

print("Done.\n")

# ------------------------------------------------------------
# Training
# ------------------------------------------------------------

print("Training...\n")

torch.cuda.reset_peak_memory_stats()

torch.cuda.synchronize()

t0 = time.perf_counter()

for epoch in range(args.epochs):

    optimizer.zero_grad()

    output = model(x)

    loss = criterion(output, y)

    loss.backward()

    optimizer.step()

    torch.cuda.synchronize()

    elapsed = time.perf_counter() - t0

    samples = (epoch + 1) * args.batch_size
    throughput = samples / elapsed

    print(
        f"Epoch {epoch+1:3d}/{args.epochs:3d} "
        f"Loss={loss.item():8.5f} "
        f"Time={elapsed:8.2f}s "
        f"Throughput={throughput:9.0f} samples/s"
    )

total = time.perf_counter() - t0

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

allocated = torch.cuda.memory_allocated() / 1024**3
reserved = torch.cuda.memory_reserved() / 1024**3
peak = torch.cuda.max_memory_allocated() / 1024**3

print()
print("=" * 70)
print("SUMMARY")
print("=" * 70)

print(f"GPU                : {gpu_name}")
print(f"Epochs             : {args.epochs}")
print(f"Batch Size         : {args.batch_size}")
print(f"Hidden Size        : {args.hidden_size}")
print(f"Training Time      : {total:.2f} s")
print(f"Average Throughput : {(args.epochs * args.batch_size) / total:.0f} samples/s")
print(f"GPU Memory Peak    : {peak:.2f} GB")
print(f"GPU Memory Current : {allocated:.2f} GB")
print(f"GPU Memory Cached  : {reserved:.2f} GB")

print("=" * 70)
print("Benchmark completed successfully.")
