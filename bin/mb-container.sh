#!/bin/bash
set -euo pipefail

container=$1
shift

singularity exec -B $(pwd):/scratch --contain ${container} sh -c "unset PYTHONHOME; unset PYTHONPATH; cd /scratch; mb.sh $*"

for job in $(ls -tr magetbrain-container-jobs/*meta)
do
    qbatch -n --header "read -r -d '' singularity_script << EOM" --header "unset PYTHONHOME; unset PYTHONPATH;" \
	--header "cd /scratch" \
        --footer "EOM" --footer "singularity exec -B $(pwd):/scratch --contain ${container} sh -c \"\$singularity_script\"" \
	$(cat $job) $(dirname $job)/$(basename $job .meta).joblist
done
