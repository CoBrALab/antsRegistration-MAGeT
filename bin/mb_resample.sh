#!/bin/bash
#mb_resample.sh labelname atlasname templatename subjectname
if [[ ${__mb_debug:-} ]]; then
  set -x
fi
set -euo pipefail

export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${THREADS_PER_COMMAND:-$(nproc)}

labelname=$1
atlas=$2
template=$3
subject=$4
subjectname=$(basename ${subject})
atlasname=$(basename ${atlas})
templatename=$(basename ${template})

if [[ ${__mb_fast:-} ]]; then
  __mb_float="--float 1"
else
  __mb_float="--float 0"
fi

#Check for subjectname == $templatename, if so, we skipped that registration, so don't apply those transforms
if [[ ${subjectname} == "${templatename}" ]]
then
  antsApplyTransforms -d 3 ${__mb_float} ${MB_VERBOSE:-} --interpolation GenericLabel -r ${subject} \
    -i $(echo ${atlas} | sed -r 's/(t1|T1w|t2|T2w).*//g')${labelname} \
    -o /tmp/${atlasname}-${templatename}-${subjectname}-${labelname} \
    -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}1_NL.xfm \
    -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}0_GenericAffine.xfm
else
  #Transforms are applied like matrix algebra, last transform on the command line is applied first
  antsApplyTransforms -d 3 ${__mb_float} ${MB_VERBOSE:-} --interpolation GenericLabel -r ${subject} \
    -i $(echo ${atlas} | sed -r 's/(t1|T1w|t2|T2w).*//g')${labelname} \
    -o /tmp/${atlasname}-${templatename}-${subjectname}-${labelname} \
    -t output/transforms/template-subject/${subjectname}/${templatename}-${subjectname}1_NL.xfm \
    -t output/transforms/template-subject/${subjectname}/${templatename}-${subjectname}0_GenericAffine.xfm \
    -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}1_NL.xfm \
    -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}0_GenericAffine.xfm
fi

ConvertImage 3 /tmp/${atlasname}-${templatename}-${subjectname}-$labelname output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-$labelname 1
rm -f /tmp/${atlasname}-${templatename}-${subjectname}-${labelname}
