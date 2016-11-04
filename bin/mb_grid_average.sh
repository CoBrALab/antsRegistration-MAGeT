#!/bin/bash
#mb_grid_average.sh subject <list of grids>
set -euo pipefail

export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${THREADS_PER_COMMAND:-$(nproc)}

subject=$1
subjectname=$(basename $subject)
subjectext=$(echo $subjectname | grep -i -o -E '(.mnc|.nii|.nii.gz|.nrrd)')
shift 1

AverageImages 3 output/grids/average/${subjectname}/${subjectname}-gridavg${subjectext} 0 "$@"
CreateJacobianDeterminantImage 3 output/grids/average/${subjectname}/${subjectname}-gridavg${subjectext} output/grids/average/${subjectname}/${subjectname}-logdet${subjectext} 1 0
CreateJacobianDeterminantImage 3 output/grids/average/${subjectname}/${subjectname}-gridavg${subjectext} output/grids/average/${subjectname}/${subjectname}-det${subjectext} 0 0

SmoothImage 3 output/grids/average/${subjectname}/${subjectname}-logdet${subjectext} 0.42466090014400952136 output/grids/average/${subjectname}/${subjectname}-logdet_1mm${subjectext} 1 0
SmoothImage 3 output/grids/average/${subjectname}/${subjectname}-logdet${subjectext} 0.84932180028801904272 output/grids/average/${subjectname}/${subjectname}-logdet_2mm${subjectext} 1 0
SmoothImage 3 output/grids/average/${subjectname}/${subjectname}-logdet${subjectext} 1.69864360057603808544 output/grids/average/${subjectname}/${subjectname}-logdet_4mm${subjectext} 1 0

SmoothImage 3 output/grids/average/${subjectname}/${subjectname}-det${subjectext} 0.42466090014400952136 output/grids/average/${subjectname}/${subjectname}-det_1mm${subjectext} 1 0
SmoothImage 3 output/grids/average/${subjectname}/${subjectname}-det${subjectext} 0.84932180028801904272 output/grids/average/${subjectname}/${subjectname}-det_2mm${subjectext} 1 0
SmoothImage 3 output/grids/average/${subjectname}/${subjectname}-det${subjectext} 1.69864360057603808544 output/grids/average/${subjectname}/${subjectname}-det_4mm${subjectext} 1 0
