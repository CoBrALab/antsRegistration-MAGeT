#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

movingfile=$1
fixedfile=$2
outputdir=$3

antsRegistration --dimensionality 3 --float 0 --collapse-output-transforms 1 ${MB_VERBOSE:-} --minc \
  --output [$outputdir/$(basename $movingfile)-$(basename $fixedfile)] \
  --winsorize-image-intensities [0.01,0.99] --use-histogram-matching 1 \
  --initial-moving-transform [$fixedfile,$movingfile,1] \
  --transform Rigid[0.1] --metric Mattes[$fixedfile,$movingfile,1] --convergence [2000x2000x2000x200,1e-6,10] --shrink-factors 8x4x2x1 --smoothing-sigmas 8x4x2x1 \
  --transform Similarity[0.1] --metric Mattes[$fixedfile,$movingfile,1] --convergence [2000x2000x2000x2000,1e-6,10] --shrink-factors 8x4x2x1 --smoothing-sigmas 8x4x2x1 \
  --transform Affine[0.1] --metric Mattes[$fixedfile,$movingfile,1] --convergence [2000x2000x2000x2000x2000,1e-6,10] --shrink-factors 8x4x2x1x1 --smoothing-sigmas 8x4x2x1x0 \
  --transform SyN[0.5,3,0] --metric CC[$fixedfile,$movingfile,1,4] --convergence [100x100x100x20,1e-6,10] --shrink-factors 8x4x2x1 --smoothing-sigmas 4x2x1x0 && \
  rm $outputdir/$(basename $movingfile)-$(basename $fixedfile)*inverse*
  #Inverses are never used, remove them right after creation (if only I could disable creation...)
