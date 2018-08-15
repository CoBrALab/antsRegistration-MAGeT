#!/bin/bash
##Registration method based on the defaults of the antsRegistrationSyN.sh script with BSplineSyN from the main distro
if [[ -n ${__mb_debug:-} ]]; then
  set -x
fi
set -euo pipefail

movingfile=$1
fixedfile=$2
outputdir=$3

if [[ -n ${__mb_fast:-} ]]; then
  __mb_float="--float 1"
  __mb_syn_metric="--metric Mattes[${fixedfile},${movingfile},1,256,None,1]"
else
  __mb_syn_metric="--metric CC[${fixedfile},${movingfile},1,4]"
  __mb_float="--float 0"
fi

antsRegistration --dimensionality 3 ${__mb_float} ${MB_VERBOSE:-} --minc \
  --output [$outputdir/$(basename $movingfile)-$(basename $fixedfile)] \
  --winsorize-image-intensities [0.005,0.995] --use-histogram-matching 0 \
  --initial-moving-transform [$fixedfile,$movingfile,1] \
  --transform Rigid[0.1] --metric Mattes[$fixedfile,$movingfile,1,32,Regular,0.25] --convergence [1000x500x250x100,1e-6,10] --shrink-factors 8x4x2x1 --smoothing-sigmas 3x2x1x0vox \
  --transform Affine[0.1] --metric Mattes[$fixedfile,$movingfile,1,32,Regular,0.25] --convergence [1000x500x250x100,1e-6,10] --shrink-factors 8x4x2x1 --smoothing-sigmas 3x2x1x0vox \
  --transform BSplineSyN[0.1,26,0,3] ${__mb_syn_metric} --convergence [100x70x50x20,1e-6,10] --shrink-factors 8x4x2x1 --smoothing-sigmas 3x2x1x0vox
