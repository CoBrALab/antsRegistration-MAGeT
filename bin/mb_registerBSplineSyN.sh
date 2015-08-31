#!/bin/bash
movingfile=$1
fixedfile=$2
outputdir=$3
movingmask=$(echo $movingfile | sed 's/t1/mask/g')
fixedmask=$(echo $fixedfile | sed 's/t1/mask/g')

antsRegistration --dimensionality 3 --float 0 --collapse-output-transforms 1 --verbose \
  --output [$outputdir/$(basename $movingfile)-$(basename $fixedfile)] \
  --winsorize-image-intensities [0.01,0.99] --use-histogram-matching 1 \
  --initial-moving-transform [$fixedfile,$movingfile,1] \
  --transform Rigid[0.2] --metric Mattes[$fixedfile,$movingfile,1,32,Random,0.25] --convergence [2000x2000x2000x0,1e-6,10] --shrink-factors 8x4x2x1 --smoothing-sigmas 3x2x1x0vox --masks [NULL,NULL] \
  --transform Affine[0.5] --metric Mattes[$fixedfile,$movingfile,1,32,Random,0.30] --convergence [2000x2000x2000x2000x0,1e-6,10] --shrink-factors 8x8x4x2x1 --smoothing-sigmas 4x3x2x1x0vox --masks [NULL,NULL] \
  --transform Affine[0.1] --metric Mattes[$fixedfile,$movingfile,1,64,Random,0.30] --convergence [2000x2000x2000x2000x2000,1e-6,10] --shrink-factors 8x6x4x2x1 --smoothing-sigmas 4x3x2x1x0vox --masks [$fixedmask,$movingmask] \
  --transform BSplineSyN[0.4,52,0] --metric CC[$fixedfile,$movingfile,1,8] --convergence [2000x2000x1000x1000x100x100,1e-6,10] --shrink-factors 10x8x6x4x2x1 --smoothing-sigmas 5x4x3x2x1x0vox --masks [$fixedmask,$movingmask]
