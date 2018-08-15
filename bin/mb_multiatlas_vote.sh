#!/bin/bash
#mb_vote.sh labelname subjectname <list of candidate labels>
if [[ -n ${__mb_debug:-} ]]; then
  set -x
fi
set -euo pipefail

export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${THREADS_PER_COMMAND:-$(nproc)}

labelname=$1
subject=$2

shift 2

subjectname=$(basename ${subject})
subjectext=$(echo ${subjectname} | grep -i -o -E '(.mnc|.nii|.nii.gz|.nrrd)')

labelname=$(echo ${labelname} | sed -r 's/(.mnc|.nii|.nii.gz|.nrrd)//g')

ImageMath 3 /tmp/${subjectname}_${labelname}${subjectext} MajorityVoting "$@"
ConvertImage 3 /tmp/${subjectname}_${labelname}${subjectext} output/multiatlas/labels/majorityvote/${subjectname}_${labelname}${subjectext} 1

rm -f /tmp/${subjectname}_${labelname}${subjectext}
