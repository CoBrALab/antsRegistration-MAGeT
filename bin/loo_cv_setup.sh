#!/bin/bash
# Generator for leave-one-out cross validation of MaGeT, shamelessly stolen from ealier script
# Start by running a ``mb.sh -- template subject resample`` with
# - high res (original atlases) as atlases with labels
# - subsampled atlases as templates (plus possibly other similar templates from a control set)
# - subsampled atlases as subjects (must have same name as atlas files)
# This primes the pipeline with all the possible registrations
# Then, run LOOCV_setup.sh
# This shuffles the atlases to create magetbrain runs with an odd number of atlases with a given atlas left out
# Afterwards links into the directory the already processed transforms and candidate labels
# Then all that is left is to run mb.sh in each directory to complete the voting stage

pool=(input/atlas/*t1.mnc)
templates=(input/template/*t1.mnc)

if [[ $4 ]]
then
  targetdir=$4
else
  targetdir=.
fi

i=0
for leaveout in "${pool[@]}"
do
  #Create a slice of array missing item i
  reamining_atlases=( "${pool[@]::$i}" "${pool[@]:$((i+1))}" )

  #Loop through remaining atlases, create all combinations nCm for odd m
  for j in $(seq 0 ${#reamining_atlases[@]})
  do
    #Generate array with missing oddmaker item using slicing again
    oddarray=( "${remaining_atlases[@]::$j}" "${remaining_atlases[@]:$((j+1))}" )
    #Call this a fold and create directory for it
    folddir=${targetdir}/LOOCV/$(basename $leaveout)/fold$j
    mkdir -p ${folddir}/input/{atlas,template,subject}
    mkdir -p ${folddir}/output/labels/majorityvote
    #Link in precomputed transforms and candidate labels
    ln -s $(readlink -f output/transforms) ${folddir}/output/transforms
    ln -s $(readlink -f output/labels/candidates) ${folddir}/output/labels/candidates
    #Do a trick of replacing _t1.mnc with * to allow bash expansion to include all label files
    tmp=("${oddarray[@]/_t1.mnc/*}")
    cp -l "${tmp[@]}" ${folddir}/input/atlas
    #Link in all templates
    cp -l "${templates[@]}" ${folddir}/input/template
    #Do a quick clever rewrite of the atlas file left out to its corresponding subject file named identically
    cp -l ${leaveout/atlas/subject} ${folddir}/input/subject
    (cd ${folddir}; mb.sh -- vote)
  done
  ((i++))
done
