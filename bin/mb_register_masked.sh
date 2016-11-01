#!/bin/bash
#Masked registration script which does an initial-whole image registration, followed by focused registrations in the region of interest
#Possible applications
# - brain masked registrations (yet to confirm is this is better than non-brain masked)
# - ROI based registration, some evidence that this is better than the default registration in the cerebellum, ROI should still be generous
#Warning: if you do ROI based registration, all labels outside the ROI will be invalid!
set -euo pipefail

movingfile=$1
fixedfile=$2
outputdir=$3
movingmask=$(echo $movingfile | sed -e 's/t1\./mask./g' | grep mask || true)
fixedmask=$(echo $fixedfile | sed  -e 's/t1\./mask./g' | grep mask || true)

antsRegistration --dimensionality 3 --float 0 --collapse-output-transforms 1 ${MB_VERBOSE:-} --minc \
  --output [$outputdir/$(basename $movingfile)-$(basename $fixedfile)] \
  --winsorize-image-intensities [0.01,0.99] --use-histogram-matching 1 \
  --initial-moving-transform [$fixedfile,$movingfile,1] \
  --transform Rigid[0.1] --metric Mattes[$fixedfile,$movingfile,1] --convergence [2000,1e-6,10] --shrink-factors 8 --smoothing-sigmas 6.794mm --masks [NULL,NULL] \
  --transform Similarity[0.1] --metric Mattes[$fixedfile,$movingfile,1] --convergence [2000,1e-6,10] --shrink-factors 4 --smoothing-sigmas 3.397mm --masks [NULL,NULL] \
  --transform Affine[0.1] --metric Mattes[$fixedfile,$movingfile,1] --convergence [2000x2000x2000,1e-6,10] --shrink-factors 4x4x2 --smoothing-sigmas 3.397x1.698x0.849mm --masks [NULL,NULL] \
  --transform Affine[0.1] --metric Mattes[$fixedfile,$movingfile,1] --convergence [2000x2000x2000x2000,1e-6,10] --shrink-factors 4x4x2x1 --smoothing-sigmas 3.397x1.698x0.849x0mm --masks [$fixedmask,$movingmask] \
  --transform SyN[0.5,3,0] --metric CC[$fixedfile,$movingfile,1,4] --convergence [400x400x400x200x25,1e-6,10] --shrink-factors 12x8x4x2x1 --smoothing-sigmas 5x4x2x1x0vox --masks [$fixedmask,$movingmask]
