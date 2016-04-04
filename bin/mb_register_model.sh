#!/bin/bash
movingfile=$1
fixedfile=$2
outputdir=$3
movingmask=$(echo $movingfile | sed -e 's/t1\./mask./g' | grep mask)
fixedmask=$(echo $fixedfile | sed  -e 's/t1\./mask./g' | grep mask)

antsRegistration --dimensionality 3 --float 0 --collapse-output-transforms 1 --verbose --minc \
  --output [$outputdir/$(basename $movingfile)] \
  --winsorize-image-intensities [0.01,0.99] --use-histogram-matching 1 \
  --initial-moving-transform [$fixedfile,$movingfile,1] \
  --transform Rigid[0.1] --metric Mattes[$fixedfile,$movingfile,1] --convergence [2000,1e-6,10] --shrink-factors 8 --smoothing-sigmas 6.794mm \
  --transform Similarity[0.1] --metric Mattes[$fixedfile,$movingfile,1] --convergence [2000,1e-6,10] --shrink-factors 4 --smoothing-sigmas 3.397mm \
  --transform Affine[0.1] --metric Mattes[$fixedfile,$movingfile,1] --convergence [2000x2000x2000,1e-6,10] --shrink-factors 4x4x2 --smoothing-sigmas 3.397x1.698x0.849mm
