#!/bin/bash
set -euo pipefail

export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${THREADS_PER_COMMAND:-$(nproc)}

tmpdir=$(mktemp -d)

movingfile=$1
fixedfile=$2
outputdir=$3
shift 3

labelfiles=( "$@" )

fixed_scaling=$(python -c "print(1.0/min(($(PrintHeader ${fixedfile} 1 | sed 's/x/\,/g'))))")

sub8mm=$(python -c "print(max(1,int(${fixed_scaling} * 8)))")
sub7mm=$(python -c "print(max(1,int(${fixed_scaling} * 7)))")
sub6mm=$(python -c "print(max(1,int(${fixed_scaling} * 6)))")
sub5mm=$(python -c "print(max(1,int(${fixed_scaling} * 5)))")
sub4mm=$(python -c "print(max(1,int(${fixed_scaling} * 4)))")
sub3mm=$(python -c "print(max(1,int(${fixed_scaling} * 3)))")
sub2mm=$(python -c "print(max(1,int(${fixed_scaling} * 2)))")
sub1mm=$(python -c "print(max(2,int(${fixed_scaling} * 1)))")

#Converting FWHM to Sigma
blur16mm=6.79457440230415234177
blur14mm=5.94525260201613329905
blur12mm=5.09593080172811425633
blur10mm=4.24660900144009521361
blur8mm=3.39728720115207617089
blur6mm=2.54796540086405712816
blur4mm=1.69864360057603808544
blur3mm=1.27398270043202856408
blur2mm=0.84932180028801904272
blur1mm=0.42466090014400952136
blur05mm=0.21233045007200476068

if [[ ${#labelfiles[@]} -gt 0 ]]
then
    if [[ ${#labelfiles[@]} -eq 1 ]]
    then
        cp "${labelfiles[@]}" ${tmpdir}/mergedmask.mnc
    else
        ImageMath 3 ${tmpdir}/mergedmask.mnc max "${labelfiles[@]}"
    fi
    ThresholdImage 3 ${tmpdir}/mergedmask.mnc ${tmpdir}/mergedmask2.mnc 0.5 255 1 0
    iMath 3 ${tmpdir}/mergedmask2.mnc MD ${tmpdir}/mergedmask2.mnc 6 1 1 1
    ExtractRegionFromImageByMask 3 ${tmpdir}/mergedmask2.mnc ${tmpdir}/cropmask.mnc ${tmpdir}/mergedmask2.mnc 1 30
    ThresholdImage 3 ${tmpdir}/cropmask.mnc ${tmpdir}/cropmask.mnc 0 255 1 1
    antsApplyTransforms -d 3 -i ${tmpdir}/cropmask.mnc -r ${tmpdir}/mergedmask.mnc -n NearestNeighbor -o ${tmpdir}/cropmask.mnc
    ImageMath 3 ${tmpdir}/regmask.mnc max ${tmpdir}/mergedmask2.mnc ${tmpdir}/cropmask.mnc
    finalaffine1="--transform Affine[0.1]     --metric GC[${fixedfile},${movingfile},1,32,Regular,1] --convergence [250x125x50,1e-6,10,1] --shrink-factors ${sub2mm}x${sub1mm}x1  --smoothing-sigmas ${blur2mm}x${blur1mm}x${blur05mm}mm --masks [NULL,${tmpdir}/regmask.mnc]"
    finalaffine2="--transform Affine[0.1]     --metric GC[${fixedfile},${movingfile},1,32,Regular,1] --convergence [500x250x125x50,1e-7,10,1] --shrink-factors ${sub2mm}x${sub2mm}x${sub1mm}x1 --smoothing-sigmas ${blur2mm}x${blur1mm}x${blur05mm}x0mm --masks [NULL,${tmpdir}/mergedmask2.mnc]"
else
    finalaffine1="--transform Affine[0.1]     --metric Mattes[${fixedfile},${movingfile},1,32,Regular,1] --convergence [250x125x0,1e-6,10,1] --shrink-factors ${sub2mm}x${sub1mm}x1  --smoothing-sigmas ${blur2mm}x${blur1mm}x${blur05mm}mm --masks [NULL,NULL]"
    finalaffine2=""
fi

if [[ ! -e ${outputdir}/$(basename ${movingfile})-$(basename ${fixedfile})0_GenericAffine.xfm ]]
then
antsRegistration --dimensionality 3 --float 0 --collapse-output-transforms 1 --verbose --minc \
  --output [${outputdir}/$(basename ${movingfile})-$(basename ${fixedfile})] \
  --use-histogram-matching 0 \
  --initial-moving-transform [${fixedfile},${movingfile},1] \
  --transform Rigid[0.1]      --metric Mattes[${fixedfile},${movingfile},1,32,Regular,0.25] --convergence [2000x1000x500x250x125,1e-6,10,1] --shrink-factors ${sub8mm}x${sub8mm}x${sub4mm}x${sub2mm}x${sub1mm} --smoothing-sigmas ${blur16mm}x${blur8mm}x${blur4mm}x${blur2mm}x${blur1mm}mm --masks [NULL,NULL] \
  --transform Similarity[0.1] --metric Mattes[${fixedfile},${movingfile},1,32,Regular,0.5] --convergence [1000x500x250x125,1e-6,10,1] --shrink-factors ${sub8mm}x${sub4mm}x${sub2mm}x${sub1mm} --smoothing-sigmas ${blur8mm}x${blur4mm}x${blur2mm}x${blur1mm}mm --masks [NULL,NULL] \
  --transform Affine[0.1]     --metric Mattes[${fixedfile},${movingfile},1,32,Regular,0.75] --convergence [500x250x125,1e-6,10,1] --shrink-factors ${sub4mm}x${sub2mm}x${sub1mm}  --smoothing-sigmas ${blur4mm}x${blur2mm}x${blur1mm}mm --masks [NULL,NULL] \
  ${finalaffine1} \
  ${finalaffine2}
fi


antsRegistration --dimensionality 3 --float 0 --collapse-output-transforms 1 --verbose --minc \
  --output [${outputdir}/$(basename ${movingfile})-$(basename ${fixedfile})] \
  --use-histogram-matching 0 \
  --initial-moving-transform ${outputdir}/$(basename ${movingfile})-$(basename ${fixedfile})0_GenericAffine.xfm \
  --transform SyN[0.25,2,0] --metric CC[${fixedfile},${movingfile},1,4] --convergence [6400x3200x1600x800x400x200x100x0,1e-6,10] \
  --shrink-factors ${sub8mm}x${sub7mm}x${sub6mm}x${sub5mm}x${sub4mm}x${sub4mm}x${sub4mm}x1 \
  --smoothing-sigmas ${blur16mm}x${blur14mm}x${blur12mm}x${blur10mm}x${blur8mm}x${blur6mm}x${blur4mm}x0mm --masks [NULL,${tmpdir}/regmask.mnc] \
  --transform SyN[0.25,3,0] --metric CC[${fixedfile},${movingfile},1,4] --convergence [400x200x100x50x25x20,1e-6,10] \
  --shrink-factors ${sub4mm}x${sub3mm}x${sub2mm}x${sub1mm}x${sub1mm}x1 \
  --smoothing-sigmas ${blur4mm}x${blur3mm}x${blur2mm}x${blur1mm}x${blur05mm}x0mm --masks [NULL,${tmpdir}/regmask.mnc]

rm -rf ${tmpdir}
