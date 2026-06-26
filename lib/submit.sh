#!/bin/bash
#
# submit.sh
#
# Submit a Python job to the Panda Cluster
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

############################################################
# Defaults
############################################################

GPU="${DEFAULT_GPU:-}"
ENV="${DEFAULT_ENV:-base}"
CPUS="${DEFAULT_CPUS:-1}"
MEM="${DEFAULT_MEM:-8G}"

JOB_NAME=""
SCRIPT=""
NODE=""
PARTITION="${DEFAULT_PARTITION:-cpu}"

############################################################
# Usage
############################################################

usage()
{
cat <<EOF

Usage:

    panda submit program.py [options]

Options

    --gpu MODEL         GPU type (5090, 1070, quadro)

    --env ENV           Conda environment

    --cpus N            CPUs per task

    --mem SIZE          Memory (e.g. 16G)

    --job-name NAME     Job name

    -h, --help          Show this help

EOF
}

############################################################
# Parse command line
############################################################

while [[ $# -gt 0 ]]
do

    case "$1" in

        --gpu)
            GPU="$2"
            shift 2
            ;;

        --env)
            ENV="$2"
            shift 2
            ;;

        --cpus)
            CPUS="$2"
            shift 2
            ;;

        --mem)
            MEM="$2"
            shift 2
            ;;

        --job-name)
            JOB_NAME="$2"
            shift 2
            ;;

        -h|--help)

            usage
            exit 0
            ;;

        -*)

            die "Unknown option: $1"
            ;;

        *)

            if [[ -z "$SCRIPT" ]]
            then
                SCRIPT="$1"
            else
                die "Only one Python script may be submitted."
            fi

            shift
            ;;

    esac

done

############################################################
# Validate
############################################################

[[ -n "$SCRIPT" ]] \
    || die "No Python script specified."

[[ -f "$SCRIPT" ]] \
    || die "Cannot find '$SCRIPT'."

[[ "$SCRIPT" == *.py ]] \
    || die "Version 1 only supports Python programs."

if [[ -z "$JOB_NAME" ]]
then
    JOB_NAME=$(basename "$SCRIPT" .py)
fi

############################################################
# GPU mapping
############################################################

if [[ -n "$GPU" ]]
then

    NODE="${GPU_NODE[$GPU]}"

    [[ -n "$NODE" ]] \
        || die "Unknown GPU '$GPU'."

    PARTITION="$NODE"

fi

############################################################
# Create temporary Slurm script
############################################################

TMPFILE=$(mktemp /tmp/panda-submit-XXXXXX.slurm)

cat > "$TMPFILE" <<EOF
#!/bin/bash
#SBATCH --job-name=$JOB_NAME
#SBATCH --partition=$PARTITION
#SBATCH --cpus-per-task=$CPUS
#SBATCH --mem=$MEM
#SBATCH --output=$LOG_DIR/slurm-%j.out
EOF

if [[ -n "$NODE" ]]
then

cat >> "$TMPFILE" <<EOF
#SBATCH --nodelist=$NODE
#SBATCH --gres=gpu:1
EOF

fi

cat >> "$TMPFILE" <<EOF

source "$CONDA_INIT"

conda activate "$ENV"

python "$SCRIPT"

EOF

############################################################
# Summary
############################################################

banner

header "Submit Job"

echo "Script        : $SCRIPT"
echo "Job Name      : $JOB_NAME"
echo "Environment   : $ENV"
echo "CPUs          : $CPUS"
echo "Memory        : $MEM"

if [[ -n "$GPU" ]]
then
    echo "GPU           : ${GPU_DESCRIPTION[$GPU]}"
    echo "Node          : $NODE"
fi

echo

############################################################
# Submit
############################################################

OUTPUT=$(sbatch "$TMPFILE")

STATUS=$?

rm -f "$TMPFILE"

[[ $STATUS -eq 0 ]] \
    || die "Submission failed."

JOBID=$(echo "$OUTPUT" | awk '{print $4}')

success "Job submitted."

echo
echo "Job ID        : $JOBID"
echo "Log file      : $LOG_DIR/slurm-${JOBID}.out"
echo
