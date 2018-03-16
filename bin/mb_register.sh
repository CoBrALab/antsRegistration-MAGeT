#!/bin/bash
set -euo pipefail
set -x
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${THREADS_PER_COMMAND:-$(nproc)}

tmpdir=$(mktemp -d)

movingfile=$1
fixedfile=$2
outputdir=$3
shift 3

movingmask=NULL
fixedmask=NULL

inputext=$(basename $movingfile | grep -o -E '(.mnc|.nii|.nii.gz|.nrrd|.hdr)')

labelfiles=( "$@" )

minimum_resolution=$(python -c "print(min(($(PrintHeader ${fixedfile} 1 | sed 's/x/\,/g'))))")


if ((${#labelfiles[@]} > 0)); then
    #Flatten all the label files into a mask
    cp ${labelfiles[0]} ${tmpdir}/mergedmask${inputext}
    if ((${#labelfiles[@]} > 1)); then
        for label in "${labelfiles[@]}"; do
            ImageMath 3 ${tmpdir}/mergedmask${inputext} addtozero ${tmpdir}/mergedmask${inputext} $label
        done
    fi
    #Binarize the labels
    ThresholdImage 3 ${tmpdir}/mergedmask${inputext} ${tmpdir}/mergedmask2${inputext} 0.5 255 1 0
    #Extract a padded region of 10mm around the ROI
    ExtractRegionFromImageByMask 3 ${tmpdir}/mergedmask2${inputext} ${tmpdir}/cropmask${inputext} ${tmpdir}/mergedmask2${inputext} 1 $(python -c "print(int(10.0/${minimum_resolution}))")
    #Set the newly extracted region to values all 1
    ThresholdImage 3 ${tmpdir}/cropmask${inputext} ${tmpdir}/cropmask${inputext} 0 255 1 1
    #Reshape the image back to the original size
    antsApplyTransforms -d 3 -i ${tmpdir}/cropmask${inputext} -r ${tmpdir}/mergedmask${inputext} -n GenericLabel -o ${tmpdir}/cropmask${inputext}
    movingmask=${tmpdir}/cropmask${inputext}
fi

if [[ ! -s ${outputdir}/$(basename ${movingfile})-$(basename ${fixedfile})0_GenericAffine.xfm ]]
then

  linear_steps=$(generate-iterations-linear.py ${minimum_resolution})
  antsRegistration --dimensionality 3 --float 0 --collapse-output-transforms 1 --verbose --minc \
    --output [${outputdir}/$(basename ${movingfile})-$(basename ${fixedfile})] \
    --use-histogram-matching 0 \
    --initial-moving-transform [${fixedfile},${movingfile},1] \
    $(eval echo ${linear_steps})
fi

nonlinear_steps=$(generate-iterations-SyN-fine.py ${minimum_resolution})
antsRegistration --dimensionality 3 --float 0 --collapse-output-transforms 1 --verbose --minc \
  --output [${outputdir}/$(basename ${movingfile})-$(basename ${fixedfile})] \
  --use-histogram-matching 0 \
  --initial-moving-transform ${outputdir}/$(basename ${movingfile})-$(basename ${fixedfile})0_GenericAffine.xfm \
  $(eval echo ${nonlinear_steps})

rm -rf ${tmpdir}
