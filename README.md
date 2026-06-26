````markdown
# 🐼 Panda Cluster Tools

**Panda Cluster Tools** is a collection of command-line utilities for managing the **Panda Cluster**, a small GPU cluster built for computational seismology, deep learning, and scientific computing.

The toolkit provides a simple and consistent interface for monitoring the cluster, deploying configuration files, submitting Slurm jobs, and checking system health.

---

## Features

- Monitor the status of the entire cluster
- Display GPU utilization and memory usage
- Deploy Slurm configuration to all nodes
- Submit Python jobs without writing Slurm scripts
- Verify cluster health
- Benchmark CPUs and GPUs

---

## Panda Cluster

The cluster is named after the famous animals of Chapultepec Zoo.

| Node | Hardware | GPU(s) | Role |
|------|----------|--------|------|
| **shuanshuan** | Intel Workstation | 2 × NVIDIA Quadro RTX 4000 | Slurm controller + compute node |
| **tohui** | AMD Ryzen 9 9950X | NVIDIA GeForce RTX 5090 | Main AI training node |
| **xinxin** | AMD Workstation | NVIDIA GeForce GTX 1070 | Secondary compute node |

Current resources:

- 3 compute nodes
- 4 NVIDIA GPUs
- Slurm Workload Manager
- Ubuntu Linux

---

## Installation

Clone the repository:

```bash
git clone https://github.com/<username>/cluster-tools.git
````

Add the executable to your `PATH`:

```bash
export PATH=$PATH:/path/to/cluster-tools/bin
```

Verify the installation:

```bash
panda
```

---

# Command Line Interface

All commands are accessed through the **panda** executable.

```bash
panda <command> [options]
```

## Available Commands

| Command     | Description                           |
| ----------- | ------------------------------------- |
| `status`    | Display the status of the cluster     |
| `gpu`       | Show GPU utilization and memory usage |
| `submit`    | Submit a Slurm job                    |
| `deploy`    | Deploy configuration files            |
| `doctor`    | Verify cluster health                 |
| `benchmark` | Benchmark CPUs and GPUs               |
| `help`      | Display help information              |

---

# Command Reference

## panda status

Display the current status of the Panda Cluster.

```bash
panda status
```

The command displays:

* Slurm controller status
* Compute node status
* Running jobs
* GPU summary
* Disk usage
* Cluster summary

Example:

```text
🐼 Panda Cluster Tools v0.1.0

============================================================
Controller
============================================================

[ OK ] Slurm controller is running.

============================================================
Nodes
============================================================

Node         State      CPU   Memory   GPU
---------------------------------------------------------
shuanshuan   idle       8     64231M   gpu:2
tohui        idle       32    126424M  gpu:1
xinxin       idle       32    31973M   gpu:1

============================================================
Jobs
============================================================

No running jobs.
```

This command provides a quick overview of the entire cluster and is typically the first command executed before submitting jobs.

---

## panda gpu

Display detailed information for every GPU in the cluster.

```bash
panda gpu
```

Information includes:

* GPU model
* Memory usage
* GPU utilization
* Temperature
* Power consumption

Example:

```text
============================================================
tohui
============================================================

GPU 0 : NVIDIA GeForce RTX 5090

Memory [███████████░░░░░░░░░░░░░░░░] 11345 / 32768 MB
GPU    [██████████████████████████]   99 %
Temp    67 °C
Power  468.4 W
```

The progress bars provide a quick visual indication of GPU memory usage and computational load.

---

## Commands Under Development

The following commands are currently under development.

| Command           | Status            |
| ----------------- | ----------------- |
| `panda submit`    | 🚧 In development |
| `panda deploy`    | 🚧 In development |
| `panda doctor`    | 🚧 In development |
| `panda benchmark` | 🚧 Planned        |

---

## Requirements

* Ubuntu Linux
* Bash 5+
* Slurm Workload Manager
* OpenSSH
* NVIDIA drivers
* CUDA Toolkit (recommended)

---

## License

MIT License

MIT License

Copyright (c) 2026 Luis Antonio Domínguez

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## Author

Luis Antonio Domínguez

Instituto de Geofísica, UNAM

```
```

