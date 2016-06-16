#!/bin/bash
#Registration method based on the defaults of the antsRegistrationSyN.sh script from the main distro
set -euo pipefail
IFS=$'\n\t'

movingfile=$1
fixedfile=$2
outputdir=$3

antsRegistration --dimensionality 3 --float 0 --collapse-output-transforms 1 ${MB_VERBOSE:-} --minc \
  --output [$outputdir/$(basename $movingfile)-$(basename $fixedfile)] \
  --winsorize-image-intensities [0.005,0.995] --use-histogram-matching 0 \
  --initial-moving-transform [$fixedfile,$movingfile,1] \
  --transform Rigid[0.1] --metric Mattes[$fixedfile,$movingfile,1,32,Regular,0.25] --convergence [1000x500x250x100x100,1e-6,10] --shrink-factors 12x8x4x2x1 --smoothing-sigmas 4x3x2x1x0vox \
  --transform Affine[0.1] --metric Mattes[$fixedfile,$movingfile,1,32,Regular,0.25] --convergence [1000x500x250x100x100,1e-6,10] --shrink-factors 12x8x4x2x1 --smoothing-sigmas 4x3x2x1x0vox \
  --transform SyN[0.1,3,0] --metric CC[$fixedfile,$movingfile,1,4] --convergence [100x100x70x50x20,1e-6,10] --shrink-factors 10x6x4x2x1 --smoothing-sigmas 5x3x2x1x0vox && \
    rm $outputdir/$(basename $movingfile)-$(basename $fixedfile)*inverse*
#Inverses are never used, remove them right after creation (if only I could disable creation...)
