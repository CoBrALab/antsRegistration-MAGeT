#!/bin/bash -e
movingfile=$1
fixedfile=$2
outputdir=$3
movingmask=$(echo $movingfile | sed -e 's/t1\./mask./g' | grep mask)
fixedmask=$(echo $fixedfile | sed  -e 's/t1\./mask./g' | grep mask)

antsRegistration --dimensionality 3 --float 0 --collapse-output-transforms 1 --verbose --minc \
  --output [$outputdir/$(basename $movingfile)-$(basename $fixedfile)] \
  --winsorize-image-intensities [0.01,0.99] --use-histogram-matching 1 \
  --initial-moving-transform [$fixedfile,$movingfile,1] \
  --transform Rigid[0.5] --metric Mattes[$fixedfile,$movingfile,1,32,Random,0.5] --convergence [2000x2000x2000x2000x0,1e-6,10] --shrink-factors 16x8x4x2x1 --smoothing-sigmas 4x3x2x1x0vox --masks [NULL,NULL] \
  --transform Affine[0.1] --metric Mattes[$fixedfile,$movingfile,1] --convergence [10000x10000x10000x10000,1e-6,10] --shrink-factors 8x4x2x1 --smoothing-sigmas 3x2x1x0vox --masks [$fixedmask,$movingmask] \
  --transform BSplineSyN[0.5,52,0] --metric CC[$fixedfile,$movingfile,1,4] --convergence [400x200x100x50x25,1e-6,10] --shrink-factors 16x8x4x2x1 --smoothing-sigmas 5x4x2x1x0vox --masks [NULL,NULL]

#Inverses are never used, remove them right after creation (if only I could disable creation...)
rm $outputdir/$(basename $movingfile)-$(basename $fixedfile)*inverse*
