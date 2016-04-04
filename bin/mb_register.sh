#!/bin/bash
movingfile=$1
fixedfile=$2
outputdir=$3
movingmask=$(echo $movingfile | sed -e 's/t1\./mask./g' | grep mask)
fixedmask=$(echo $fixedfile | sed  -e 's/t1\./mask./g' | grep mask)
initalmovingxfm=$(dirname $(dirname $outputdir))/modelspace/$(basename $movingfile)0_GenericAffine.xfm
initalfixedxfm=$(dirname $(dirname $outputdir))/modelspace/$(basename $fixedfile)0_GenericAffine.xfm

echo $initalmovingxfm
echo $initalfixedxfm

if [[ -s $initialmovingxfm && -s $initalfixedxfm ]]
then
    initaltransform="--initial-moving-transform $initalmovingxfm --initial-fixed-transform $initalfixedxfm"
else
    initaltransform="--initial-moving-transform [$fixedfile,$movingfile,1]"
fi

exit

antsRegistration --dimensionality 3 --float 0 --collapse-output-transforms 1 --verbose --minc \
  --output [$outputdir/$(basename $movingfile)-$(basename $fixedfile)] \
  --winsorize-image-intensities [0.01,0.99] --use-histogram-matching 1 \
  ${initaltransform} \
  --transform Rigid[0.1] --metric Mattes[$fixedfile,$movingfile,1] --convergence [2000,1e-6,10] --shrink-factors 8 --smoothing-sigmas 6.794mm \
  --transform Similarity[0.1] --metric Mattes[$fixedfile,$movingfile,1] --convergence [2000,1e-6,10] --shrink-factors 4 --smoothing-sigmas 3.397mm \
  --transform Affine[0.1] --metric Mattes[$fixedfile,$movingfile,1] --convergence [2000x2000x2000,1e-6,10] --shrink-factors 4x4x2 --smoothing-sigmas 3.397x1.698x0.849mm \
  --transform SyN[0.5,3,0] --metric CC[$fixedfile,$movingfile,1,4] --convergence [400x400x400x200x25,1e-6,10] --shrink-factors 12x8x4x2x1 --smoothing-sigmas 5x4x2x1x0vox && \
    rm $outputdir/$(basename $movingfile)-$(basename $fixedfile)*inverse*
#Inverses are never used, remove them right after creation (if only I could disable creation...)
