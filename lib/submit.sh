#!/bin/bash 
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

ALL_NODES=0
JOB_NAME=""
SCRIPT=""
SCRIPT_ARGS=""
NODE=""
PARTITION="${DEFAULT_PARTITION:-cpu}"
WAIT=0

############################################################
# Usage
############################################################

usage()
{
cat <<EOF

Usage:

    panda submit program.py [options]

Options

    --node NAME        Submit to a specific node

    --gpu MODEL         GPU type (5090, 1070, quadro)

    --env ENV           Conda environment

    --cpus N            CPUs per task

    --mem SIZE          Memory (e.g. 16G)

    --job-name NAME     Job name

    --args ARG          Argument passed to the Python script

    --wait              Wait for the job to finish and retrieve the log

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
	--node)
            NODE="$2"
            shift 2
            ;;

       --wait)
            WAIT=1
            shift
            ;;
--all)
    ALL_NODES=1
    shift
    ;;


        --mem)
            MEM="$2"
            shift 2
            ;;

        --job-name)
            JOB_NAME="$2"
            shift 2
            ;;
	--args)
	    SCRIPT_ARGS="$2"
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

LOCAL_SCRIPT=$(realpath "$SCRIPT")
REMOTE_SCRIPT="$LOCAL_SCRIPT"

############################################################
# Validate mutually exclusive node selection options
############################################################

COUNT=0

[[ -n "$NODE" ]] && ((COUNT++))
[[ -n "$GPU" ]] && ((COUNT++))
[[ "$ALL_NODES" -eq 1 ]] && ((COUNT++))

if [[ $COUNT -gt 1 ]]
then
    die "Use only one of --node, --gpu or --all."
fi

############################################################
# GPU mapping
############################################################

if [[ -n "$GPU" ]]
then
    NODE="${GPU_NODE[$GPU]}"

    [[ -n "$NODE" ]] \
        || die "Unknown GPU '$GPU'."
fi

############################################################
# Translate paths
############################################################

LOCAL_ROOT="${PATH_MAP[$HOSTNAME]}"
LOCAL_REPO_ROOT="${REPO_MAP[$HOSTNAME]}"

if [[ -n "$NODE" ]]; then

    REMOTE_ROOT="${PATH_MAP[$NODE]}"
    REMOTE_REPO_ROOT="${REPO_MAP[$NODE]}"

    # Research path
    if [[ -n "$REMOTE_ROOT" && -n "$LOCAL_ROOT" ]]; then
        REMOTE_SCRIPT="${LOCAL_SCRIPT/$LOCAL_ROOT/$REMOTE_ROOT}"
    fi

    # Repository path
    if [[ -n "$REMOTE_REPO_ROOT" && -n "$LOCAL_REPO_ROOT" ]]; then
        REMOTE_SCRIPT="${REMOTE_SCRIPT/$LOCAL_REPO_ROOT/$REMOTE_REPO_ROOT}"
    fi

else

    # SLURM will choose the execution node.
    # The repository path will be resolved inside the job.
    REMOTE_SCRIPT="$LOCAL_SCRIPT"

fi

############################################################
# Panda repository path
############################################################

LOCAL_PANDA_ROOT="$PANDA_HOME"

if [[ -n "$NODE" ]]; then
    REMOTE_PANDA_ROOT="${PANDA_ROOT[$NODE]}"

    if [[ "$REMOTE_SCRIPT" == "$LOCAL_PANDA_ROOT/"* ]]; then
        REMOTE_SCRIPT="${REMOTE_SCRIPT/$LOCAL_PANDA_ROOT/$REMOTE_PANDA_ROOT}"
    fi

    PANDA_REMOTE="$REMOTE_PANDA_ROOT"
else
    PANDA_REMOTE=""
fi

############################################################
# Working directory
############################################################

if [[ -n "$NODE" ]]; then
    REMOTE_WORKDIR="$(dirname "$REMOTE_SCRIPT")"
else
    REMOTE_WORKDIR=""
fi

############################################################
# Job name
############################################################

if [[ -z "$JOB_NAME" ]]
then
    JOB_NAME=$(basename "$LOCAL_SCRIPT")
    JOB_NAME="${JOB_NAME%.*}"
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

if [[ -n "$NODE" ]]; then
    cat >> "$TMPFILE" <<EOF
#SBATCH --nodelist=$NODE
#SBATCH --chdir=$REMOTE_WORKDIR
EOF
fi

if [[ -n "$GPU" ]]; then
    cat >> "$TMPFILE" <<EOF
#SBATCH --gres=gpu:1
EOF
fi

cat >> "$TMPFILE" <<EOF

# Values determined on the submission node
LOCAL_SCRIPT="$LOCAL_SCRIPT"
LOCAL_REPO_ROOT="$LOCAL_REPO_ROOT"

# Initialize Conda
eval "\$(conda shell.bash hook)"
conda activate "$ENV"

############################################################
# Resolve paths on the execution node
############################################################

if [[ -z "$NODE" ]]; then

    case "\$SLURMD_NODENAME" in
        shuanshuan)
            REMOTE_REPO_ROOT="/home/lantonio/Repositories"
            PANDA_REMOTE="/home/lantonio/Repositories/panda-cluster-tools"
            ;;
        tohui)
            REMOTE_REPO_ROOT="/data/antonio/Repositories"
            PANDA_REMOTE="/data/antonio/Repositories/panda-cluster-tools"
            ;;
        xinxin)
            REMOTE_REPO_ROOT="/home/lantonio/Repositories"
            PANDA_REMOTE="/home/lantonio/Repositories/panda-cluster-tools"
            ;;
        *)
            echo "[FAIL] Unknown execution node: \$SLURMD_NODENAME"
            exit 1
            ;;
    esac

    REMOTE_SCRIPT="\$LOCAL_SCRIPT"

    if [[ -n "\$LOCAL_REPO_ROOT" ]]; then
        REMOTE_SCRIPT="\${REMOTE_SCRIPT/\$LOCAL_REPO_ROOT/\$REMOTE_REPO_ROOT}"
    fi

else

    REMOTE_SCRIPT="$REMOTE_SCRIPT"
    PANDA_REMOTE="$PANDA_REMOTE"

fi

REMOTE_WORKDIR="\$(dirname "\$REMOTE_SCRIPT")"

cd "\$REMOTE_WORKDIR" || exit 1

echo "Running on node: \$SLURMD_NODENAME"
echo "Script:          \$REMOTE_SCRIPT"
echo "Working dir:     \$REMOTE_WORKDIR"
echo "Panda:           \$PANDA_REMOTE"

START=\$(date +%s)

############################################################
# Execute program
############################################################

case "\$REMOTE_SCRIPT" in

    *.py)
        python "\$REMOTE_SCRIPT" "$SCRIPT_ARGS"
        ;;

    *.sh)
        bash "\$REMOTE_SCRIPT"
        ;;

    *.jl)
        julia "\$REMOTE_SCRIPT"
        ;;

    *)
        if [[ -x "\$REMOTE_SCRIPT" ]]; then
            "\$REMOTE_SCRIPT"
        else
            echo "[FAIL] Unsupported file type: \$REMOTE_SCRIPT"
            exit 1
        fi
        ;;

esac

EXITCODE=\$?

END=\$(date +%s)
RUNTIME=\$((END-START))

"\$PANDA_REMOTE/bin/panda" finish \
    "\$SLURM_JOB_ID" \
    "\$EXITCODE" \
    "\$RUNTIME"

exit "\$EXITCODE"

EOF


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

if [[ -n "$NODE" ]]; then
    cat >> "$TMPFILE" <<EOF
#SBATCH --nodelist=$NODE
#SBATCH --chdir=$REMOTE_WORKDIR
EOF
fi

if [[ -n "$GPU" ]]; then
    cat >> "$TMPFILE" <<EOF
#SBATCH --gres=gpu:1
EOF
fi

cat >> "$TMPFILE" <<EOF

# Values determined on the submission node
LOCAL_SCRIPT="$LOCAL_SCRIPT"
LOCAL_REPO_ROOT="$LOCAL_REPO_ROOT"

# Initialize Conda
eval "\$(conda shell.bash hook)"
conda activate "$ENV"

############################################################
# Resolve paths on the execution node
############################################################

if [[ -z "$NODE" ]]; then

    case "\$SLURMD_NODENAME" in
        shuanshuan)
            REMOTE_REPO_ROOT="/home/lantonio/Repositories"
            PANDA_REMOTE="/home/lantonio/Repositories/panda-cluster-tools"
            ;;
        tohui)
            REMOTE_REPO_ROOT="/data/antonio/Repositories"
            PANDA_REMOTE="/data/antonio/Repositories/panda-cluster-tools"
            ;;
        xinxin)
            REMOTE_REPO_ROOT="/home/lantonio/Repositories"
            PANDA_REMOTE="/home/lantonio/Repositories/panda-cluster-tools"
            ;;
        *)
            echo "[FAIL] Unknown execution node: \$SLURMD_NODENAME"
            exit 1
            ;;
    esac

    REMOTE_SCRIPT="\$LOCAL_SCRIPT"

    if [[ -n "\$LOCAL_REPO_ROOT" ]]; then
        REMOTE_SCRIPT="\${REMOTE_SCRIPT/\$LOCAL_REPO_ROOT/\$REMOTE_REPO_ROOT}"
    fi

else

    REMOTE_SCRIPT="$REMOTE_SCRIPT"
    PANDA_REMOTE="$PANDA_REMOTE"

fi

REMOTE_WORKDIR="\$(dirname "\$REMOTE_SCRIPT")"

cd "\$REMOTE_WORKDIR" || exit 1

echo "Running on node: \$SLURMD_NODENAME"
echo "Script:          \$REMOTE_SCRIPT"
echo "Working dir:     \$REMOTE_WORKDIR"
echo "Panda:           \$PANDA_REMOTE"

START=\$(date +%s)

############################################################
# Execute program
############################################################

case "\$REMOTE_SCRIPT" in

    *.py)
        python "\$REMOTE_SCRIPT" "$SCRIPT_ARGS"
        ;;

    *.sh)
        bash "\$REMOTE_SCRIPT"
        ;;

    *.jl)
        julia "\$REMOTE_SCRIPT"
        ;;

    *)
        if [[ -x "\$REMOTE_SCRIPT" ]]; then
            "\$REMOTE_SCRIPT"
        else
            echo "[FAIL] Unsupported file type: \$REMOTE_SCRIPT"
            exit 1
        fi
        ;;

esac

EXITCODE=\$?

END=\$(date +%s)
RUNTIME=\$((END-START))

"\$PANDA_REMOTE/bin/panda" finish \
    "\$SLURM_JOB_ID" \
    "\$EXITCODE" \
    "\$RUNTIME"

exit "\$EXITCODE"

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

if [[ -n "$SCRIPT_ARGS" ]]
then
    echo "Arguments     : $SCRIPT_ARGS"
fi

if [[ -n "$NODE" ]]
then
    echo "Node          : $NODE"
fi

if [[ -n "$GPU" ]]
then
    echo "GPU           : ${GPU_DESCRIPTION[$GPU]}"
fi

echo

############################################################
# Submit
############################################################

OUTPUT=$(sbatch "$TMPFILE")

STATUS=$?

echo "SBATCH script saved as:"
echo "$TMPFILE"

#rm -f "$TMPFILE"

[[ $STATUS -eq 0 ]] \
    || die "Submission failed."


JOBID=$(echo "$OUTPUT" | awk '{print $4}')
LOGFILE="$LOG_DIR/slurm-${JOBID}.out"
NODE_NAME="${NODE:-auto}"

#
# Save metadata locally
#
cat > "$JOB_DIR/${JOBID}.conf" <<EOF
NODE=$NODE
LOGFILE=$LOG_DIR/slurm-${JOBID}.out
EOF

#
# Copy metadata to the execution node
#
push_job_metadata "$JOBID" "$NODE"

#
# Append to history
#
USER_NAME=$(id -un)

printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$JOBID" \
    "$USER_NAME"  \
    "$(date '+%Y-%m-%d %H:%M:%S')" \
    "-" \
    "PENDING" \
    "-" \
    "-" \
    "$JOB_NAME" \
    "$NODE_NAME" \
    "$CPUS" \
    "$MEM" \
    "$PWD" \
    "$LOCAL_SCRIPT" \
    "$LOGFILE" \
>> "$HISTORY_FILE"

success "Job submitted."


echo
echo "Job ID        : $JOBID"
echo "Log file      : $LOG_DIR/slurm-${JOBID}.out"
echo


if [[ $WAIT -eq 1 ]]
then
    info "Waiting for job to finish..."

    while squeue -h -j "$JOBID" | grep -q .
    do
        sleep 2
    done

    info "Retrieving log..."

    if [[ "$NODE" == "$HOSTNAME" ]]
    then
       info "Log already available locally."
    else
       rsync -a \
          "$NODE:$LOGFILE" \
          "$HOME/clusterlogs/Logs/"
    fi


    success "Log copied."

    echo
    echo "Local log:"
    echo "    $HOME/clusterlogs/Logs/slurm-${JOBID}.out"
fi



