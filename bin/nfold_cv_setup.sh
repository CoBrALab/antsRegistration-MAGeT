#!/bin/bash
# Cross validator for MaGeT, shamelessly stolen from ealier script
# Start by running a ``mb.sh -- atlas template resample`` run with all inputs
# as atlases, templates and subjects. This primes the pipeline with all the
# possible candidate labels.
# Then, run or submit a job of nfold_cv_setup.sh <nfolds> <natlases> <ntemplates>
# This shuffles the list of inputs and creates <nfolds> random samples satisftying
# <natlases> and <ntemplates> and links into the directory the already
# processed transforms and candidate labels
# Then ``mb.sh -- vote`` is run for each fold, producing final labels
# Finally, the collection script is done and the folds are cleaned up
set -euo pipefail

nfolds=$1
natlases=$2
ntemplates=$3
pool=(input/atlas/*t1.mnc)

if [[ $4 ]]
then
  targetdir=$4
else
  targetdir=.
fi

for fold in $(seq ${nfolds})
do
  #Shuffle inputs in a random list using sort
  pool=($(printf "%s\n" "${pool[@]}" | sort -R))
  #Since list is now random, slice array according to numbers provided before
  atlases=("${pool[@]:0:${natlases}}")
  subjects=("${pool[@]:${natlases}}")
  templates=("${subjects[@]:0:${ntemplates}}")

  #Setup folders for random run
  folddir=${targetdir}/NFOLDCV/${natlases}atlases_${ntemplates}templates_fold${fold}
  mkdir -p ${folddir}/input/{atlas,template,subject}
  mkdir -p ${folddir}/output/labels/majorityvote

  #Link in precomputed transforms and candidate labels
  ln -s "$(readlink -f output/transforms)" ${folddir}/output/transforms
  ln -s "$(readlink -f output/labels/candidates)" ${folddir}/output/labels/candidates

  #Do a trick of replacing _t1.mnc with * to allow bash expansion to include all label files
  tmp=("${atlases[@]/_t1.mnc/*}")
  cp -l ${tmp[@]} ${folddir}/input/atlas
  cp -l "${templates[@]}" ${folddir}/input/template
  cp -l "${subjects[@]}" ${folddir}/input/subject
  (cd ${folddir}; mb.sh -- vote)
done

nfold_cv_collect.sh ${natlases}atlases_${ntemplates}templates.csv ${natlases}atlases_${ntemplates}templates ${targetdir} && rm -rf ${targetdir}/NFOLDCV/${natlases}atlases_${ntemplates}templates_fold*
