#!/bin/bash
#mb_resample.sh labelname atlasname templatename subjectname
set -euo pipefail
IFS=$'\n\t'

labelname=$1
atlasname=$2
templatename=$3
subject=$4
subjectname=$(basename $subject)

#Here, we do a check for the presence of morpho transforms, if they exist
#If they do, push a transform to the end of the transform stack
if [[ -s output/transforms/modelspace/${subjectname}0_GenericAffine.xfm ]]
    morphosubjecttransform=" -t [output/transforms/modelspace/${subjectname}0_GenericAffine.xfm,1]"
else
    morphosubjecttransform=""
fi


#Check for subjectname == $templatename, if so, we skipped that registration, so don't apply those transforms
if [[ ${subjectname} = ${templatename} ]]
then
echo antsApplyTransforms -d 3 --verbose --interpolation GenericLabel -r ${subject} \
    -i input/atlas/$(echo $atlasname | sed -E "s/t1\.(nii|nii\.gz|mnc)/${labelname}/g") \
    -o output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-$labelname \
    ${morphosubjecttransform} \
    -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}1_NL.xfm \
    -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}0_GenericAffine.xfm \
else
#Transforms are applied like matrix algebra, last transform on the command line is applied first
echo antsApplyTransforms -d 3 --verbose --interpolation GenericLabel -r ${subject} \
    -i input/atlas/$(echo $atlasname | sed -E "s/t1\.(nii|nii\.gz|mnc)/${labelname}/g") \
    -o output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-$labelname \
    ${morphosubjecttransform} \
    -t output/transforms/template-subject/${subjectname}/${templatename}-${subjectname}1_NL.xfm \
    -t output/transforms/template-subject/${subjectname}/${templatename}-${subjectname}0_GenericAffine.xfm \
    -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}1_NL.xfm \
    -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}0_GenericAffine.xfm \
fi

echo ConvertImage 3 /tmp/${atlasname}-${templatename}-${subjectname}-$labelname output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-$labelname 1
echo rm /tmp/${atlasname}-${templatename}-${subjectname}-$labelname
