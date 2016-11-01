#!/bin/bash
set -euo pipefail

export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${THREADS_PER_COMMAND:-$(nproc)}

movingfile=$1
fixedfile=$2
outputdir=$3

antsRegistration --dimensionality 3 --float 0 --collapse-output-transforms 1 ${MB_VERBOSE:-} --minc \
  --output [$outputdir/$(basename $movingfile)-$(basename $fixedfile)] \
  --winsorize-image-intensities [0.01,0.99] --use-histogram-matching 1 \
  --initial-moving-transform [$fixedfile,$movingfile,1] \
  --transform Rigid[0.1] --metric Mattes[$fixedfile,$movingfile,1,32,Regular,0.25] --convergence [2000x1000x500x250x100x0x0,1e-6,10] --shrink-factors 12x10x8x6x4x2x1 --smoothing-sigmas 10x8x6x4x2x1x0 \
  --transform Similarity[0.1] --metric Mattes[$fixedfile,$movingfile,1,32,Regular,0.25] --convergence [1000x500x250x100x100x0,1e-6,10] --shrink-factors 10x8x6x4x2x1 --smoothing-sigmas 8x6x4x2x1x0 \
  --transform Affine[0.1] --metric Mattes[$fixedfile,$movingfile,1] --convergence [500x250x100x100x100,1e-6,10] --shrink-factors 8x6x4x2x1 --smoothing-sigmas 6x4x2x1x0 \
  --transform SyN[0.5,3,0] --metric CC[$fixedfile,$movingfile,1,4] --convergence [500x250x100x100x0,1e-6,10] --shrink-factors 8x6x4x2x1 --smoothing-sigmas 6x4x2x1x0mm \
  --transform SyN[0.5,3,0] --metric CC[$fixedfile,$movingfile,1,4] --convergence [100x25,1e-6,10] --shrink-factors 2x1 --smoothing-sigmas 1x0
