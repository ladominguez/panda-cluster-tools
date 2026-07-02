JOBID="$1"

source "$HOME/.panda/jobs/${JOBID}.conf"

mkdir -p "$HOME/clusterlogs/Logs"

scp \
    "$NODE:$LOGFILE" \
    "$HOME/clusterlogs/Logs/"
