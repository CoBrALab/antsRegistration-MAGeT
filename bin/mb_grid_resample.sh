#!/bin/bash
#mb_grid_resample.sh atlasname templatename subjectname
set -euo pipefail

export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${THREADS_PER_COMMAND:-$(nproc)}

atlas=$1
template=$2
subject=$3
model=$4
subjectname=$(basename $subject)
atlasname=$(basename $atlas)
templatename=$(basename $template)
modelname=$(basename $model)
tmpdir=$(mktemp -d)

#Check for subjectname == $templatename, if so, we skipped that registration, so don't apply those transforms
if [[ ${subjectname} == "${templatename}" ]]
then
  #In this case, we just resample the atlas-template grid then combine with the atlas-model grid
  antsApplyTransforms -d 3 ${MB_VERBOSE:-} --interpolation BSpline -r ${model} \
    -i output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}1_inverse_NL_grid_0.mnc \
    -o ${tmpdir}/template-atlas-grid.mnc \
    -t input/model/transforms/${atlasname}-${modelname}0_GenericAffine.xfm \
    -t [output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}0_GenericAffine.xfm,1]
  antsApplyTransforms -d 3 ${MB_VERBOSE:-} --interpolation BSpline -r ${model} \
    -o [output/grids/resampled/${subjectname}/${atlasname}-${templatename}-${subjectname},1] \
    -t input/model/transforms/${atlasname}-${modelname}_grid.mnc \
    -t ${tmpdir}/template-atlas-grid.mnc
else
  #Here we need to resample the atlas-template grid
  antsApplyTransforms -d 3 ${MB_VERBOSE:-} --interpolation BSpline -r ${model} \
    -i output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}1_inverse_NL_grid_0.mnc \
    -o ${tmpdir}/template-atlas-grid.mnc \
    -t input/model/transforms/${atlasname}-${modelname}0_GenericAffine.xfm \
    -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}0_GenericAffine_inverse.xfm
  antsApplyTransforms -d 3 ${MB_VERBOSE:-} --interpolation BSpline -r ${model} \
    -i output/transforms/template-subject/${subjectname}/${templatename}-${subjectname}1_inverse_NL_grid_0.mnc \
    -o ${tmpdir}/subject-template-grid.mnc \
    -t input/model/transforms/${atlasname}-${modelname}0_GenericAffine.xfm \
    -t [output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}0_GenericAffine.xfm,1] \
    -t [output/transforms/template-subject/${subjectname}/${templatename}-${subjectname}0_GenericAffine.xfm,1]
  antsApplyTransforms -d 3 ${MB_VERBOSE:-} --interpolation BSpline -r ${model} \
    -o [output/grids/resampled/${subjectname}/${atlasname}-${templatename}-${subjectname},1] \
    -t input/model/transforms/${atlasname}-${modelname}_grid.mnc \
    -t ${tmpdir}/template-atlas-grid.mnc \
    -t ${tmpdir}/subject-template-grid.mnc
fi

rm -rf ${tmpdir}
