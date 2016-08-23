#!/bin/bash
#mb_resample.sh labelname atlasname templatename subjectname
set -euo pipefail
IFS=$'\n\t'

export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${THREADS_PER_COMMAND:-$(nproc)}

labelname=$1
atlas=$2
template=$3

atlasname=$(basename $atlas)
templatename=$(basename $template)

#Transforms are applied like matrix algebra, last transform on the command line is applied first
antsApplyTransforms -d 3 ${MB_VERBOSE:-} --interpolation GenericLabel -r ${template} \
    -i $(echo $atlas | sed -E "s/t1\.(nii|nii\.gz|mnc)/${labelname}/g") \
    -o /tmp/${atlasname}-${templatename}-${labelname} \
    -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}1_NL.xfm \
    -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}0_GenericAffine.xfm

ConvertImage 3 /tmp/${atlasname}-${templatename}-${labelname} output/multiatlas/labels/candidates/${templatename}/${atlasname}-${templatename}-${labelname} 1
rm -f /tmp/${atlasname}-${templatename}-${labelname}
