#!/bin/bash
set -euo pipefail

export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${THREADS_PER_COMMAND:-$(nproc)}

movingfile=$1
fixedfile=$2
outputdir=$3
movingmask=$(dirname $movingfile)/$(basename $movingfile | sed -e 's/_t1\./_mask./g' || true)
fixedmask=$(dirname $fixedfile)/$(basename $fixedfile | sed  -e 's/_t1\./_mask./g' || true)

fixed_scaling=$(python -c "print(1.0/min(($(PrintHeader $fixedfile 1 | sed 's/x/\,/g'))))")


if [[ -s $fixedmask && -s $movingmask ]]; then
initmaskarg="--masks [NULL,NULL]"
finalmaskarg="--masks [$fixedmask,$movingmask]"
finalstage="--transform BSplineSyN[0.1,3,0,3] --metric Mattes[$fixedfile,$movingfile,1,64,Regular,1] --convergence [20,1e-6,10] --shrink-factors 1 --smoothing-sigmas 0 $finalmaskarg"
elif [[ -s $fixedmask && ! -s $movingmask ]]; then
initmaskarg="--masks [NULL,NULL]"
finalmaskarg="--masks [$fixedmask,NULL]"
finalstage="--transform BSplineSyN[0.1,3,0,3] --metric Mattes[$fixedfile,$movingfile,1,64,Regular,1] --convergence [20,1e-6,10] --shrink-factors 1 --smoothing-sigmas 0 $finalmaskarg"
elif [[ ! -s $fixedmask && -s $movingmask ]]; then
initmaskarg="--masks [NULL,NULL]"
finalmaskarg="--masks [NULL,$movingmask]"
finalstage="--transform BSplineSyN[0.1,3,0,3] --metric Mattes[$fixedfile,$movingfile,1,64,Regular,1] --convergence [20,1e-6,10] --shrink-factors 1 --smoothing-sigmas 0 $finalmaskarg"
elif [[ ! -s $fixedmask && ! -s $movingmask ]]; then
initmaskarg=""
finalmaskarg=""
finalstage="--transform BSplineSyN[0.1,3,0,3] --metric Mattes[$fixedfile,$movingfile,1,32,Regular,1] --convergence [20,1e-6,10] --shrink-factors 1 --smoothing-sigmas 0"
fi

#Multi-stage registration modelled on bestlinreg_g for linear components
#Registration based on antsRegistrationSyN.sh for Bspline components
#Scaling parameter is computed to keep the voxel resolution to certain scales in mm
#Doing this makes the script more resolution independent
#antsRegistration currently complains at the rigid stage about blur kernels, testing shows the impact on the actual blur is minimal

antsRegistration --dimensionality 3 --float 1 --collapse-output-transforms 1 ${MB_VERBOSE:-} --minc \
  --output [$outputdir/$(basename $movingfile)-$(basename $fixedfile)] \
  --winsorize-image-intensities [0.005,0.995] --use-histogram-matching 1 \
  --initial-moving-transform [$fixedfile,$movingfile,1] \
  --transform Rigid[0.1]      --metric Mattes[$fixedfile,$movingfile,1,32,Regular,0.25] --convergence [2000,1e-6,10,1] --shrink-factors $(python -c "print(max(1,int($fixed_scaling * 8)))") --smoothing-sigmas 6.7945mm  $initmaskarg \
  --transform Similarity[0.1] --metric Mattes[$fixedfile,$movingfile,1,32,Regular,0.25] --convergence [1000,1e-6,10,1] --shrink-factors $(python -c "print(max(1,int($fixed_scaling * 4)))") --smoothing-sigmas 3.3973mm  $initmaskarg \
  --transform Affine[0.1]     --metric Mattes[$fixedfile,$movingfile,1,32,Regular,0.5] --convergence [500x250,1e-6,10,1] --shrink-factors $(python -c "print(max(1,int($fixed_scaling * 4)))")x$(python -c "print(int($fixed_scaling * 4))") --smoothing-sigmas 3.3973x1.6986mm $initmaskarg \
  --transform Affine[0.1]     --metric Mattes[$fixedfile,$movingfile,1,32,Regular,1] --convergence [175x100x0,1e-6,10,1] --shrink-factors $(python -c "print(max(1,int($fixed_scaling * 4)))")x$(python -c "print(max(1,int($fixed_scaling * 2)))")x1 --smoothing-sigmas 0.8493x0.4247x0mm  $finalmaskarg \
  --transform BSplineSyN[0.1,26,0,3] --metric Mattes[$fixedfile,$movingfile,1,32,Regular,1] --convergence [100x100x100x0x0,1e-6,10] \
  --shrink-factors $(python -c "print(max(1,int($fixed_scaling * 8)))")x$(python -c "print(max(1,int($fixed_scaling * 4)))")x$(python -c "print(max(1,int($fixed_scaling * 2)))")x$(python -c "print(max(1,int($fixed_scaling * 1)))")x1 \
  --smoothing-sigmas 3x2x1x0x0mm $initmaskarg \
  $finalstage