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

ALL_NODES=0
JOB_NAME=""
SCRIPT=""
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


SCRIPT=$(realpath "$SCRIPT")

LOCAL_ROOT="${PATH_MAP[$HOSTNAME]}"
REMOTE_ROOT="${PATH_MAP[$NODE]}"

if [[ -n "$LOCAL_ROOT" && -n "$REMOTE_ROOT" ]]; then
    SCRIPT="${SCRIPT/$LOCAL_ROOT/$REMOTE_ROOT}"
fi

case "$SCRIPT" in
    *.py)
        RUN_COMMAND="python \"$SCRIPT\""
        ;;

    *.sh)
        RUN_COMMAND="bash \"$SCRIPT\""
        ;;

    *.jl)
        RUN_COMMAND="julia \"$SCRIPT\""
        ;;

    *)
        if [[ -x "$SCRIPT" ]]; then
            RUN_COMMAND="\"$SCRIPT\""
        else
            die "Unsupported file type: $(basename "$SCRIPT")"
        fi
        ;;
esac


if [[ -z "$JOB_NAME" ]]
then
    JOB_NAME=$(basename "$SCRIPT")
    JOB_NAME="${JOB_NAME%.*}"
fi

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
#SBATCH --chdir=$(dirname "$SCRIPT")
EOF

if [[ -n "$NODE" ]]
then

cat >> "$TMPFILE" <<EOF
#SBATCH --nodelist=$NODE
#SBATCH --gres=gpu:1
EOF

fi


PANDA_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PANDA_REMOTE="$PANDA_ROOT"

if [[ -n "$LOCAL_ROOT" && -n "$REMOTE_ROOT" ]]; then
    PANDA_REMOTE="${PANDA_ROOT/$LOCAL_ROOT/$REMOTE_ROOT}"
fi

cat >> "$TMPFILE" <<EOF


# Initialize Conda on the execution node

# Initialize Conda
eval "\$(conda shell.bash hook)"


conda activate "$ENV"

cd "$(dirname "$SCRIPT")" || exit 1

type -a panda

START=\$(date +%s)

$RUN_COMMAND


END=\$(date +%s)
RUNTIME=\$((END-START))


"$PANDA_REMOTE/bin/panda" finish \
    "\$SLURM_JOB_ID" \
    "\$EXITCODE" \
    "\$RUNTIME"

EXITCODE=$?

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

printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$JOBID" \
    "$(date '+%Y-%m-%d %H:%M:%S')" \
    "$JOB_NAME" \
    "$NODE_NAME" \
    "$CPUS" \
    "$MEM" \
    "$PWD" \
    "$SCRIPT" \
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


cat > "$JOB_DIR/${JOBID}.conf" <<EOF
NODE=$NODE
LOGFILE=$LOG_DIR/slurm-${JOBID}.out
EOF

