#!/bin/bash
# Generator for cross validation of MaGeT, shamelessly stolen from ealier script
# Start by running a mb run with all inputs as atlases, templates and subjects, skip voting
# This primes the pipeline with all the possible registrations
# Then, run nfold_cv_setup.sh <nfolds> <natlases> <ntemplates>
# This shuffles the list of inputs and creates <nfolds> random samples satisftying
# <natlases> and <ntemplates>
# Afterwards links into the directory the already processed transforms and candidate labels
# Then all that is left is to run mb.sh in each directory to complete the voting stage

nfolds=$1
natlases=$2
ntemplates=$3
pool=(input/atlas/*t1.mnc)

for fold in $(seq $nfolds)
do
    #Shuffle inputs in a random list using sort
    pool=($(printf "%s\n" "${pool[@]}" | sort -R))
    #Since list is now random, slice array according to numbers provided before
    atlases=("${pool[@]:0:$natlases}")
    subjects=("${pool[@]:$natlases}")
    templates=("${subjects[@]:0:$ntemplates}")

    #Setup folders for random run
    folddir=NFOLDCV/${natlases}atlases_${ntemplates}templates_fold$fold
    mkdir -p $folddir/input/{atlas,template,subject}
    mkdir -p $folddir/output/labels/majorityvote

    #Link in precomputed transforms and candidate labels
    ln -s $(readlink -f output/transforms) $folddir/output/transforms
    ln -s $(readlink -f output/labels/candidates) $folddir/output/labels/candidates

    #Do a trick of replacing _t1.mnc with * to allow bash expansion to include all label files
    tmp=("${atlases[@]/_t1.mnc/*}")
    cp -l ${tmp[@]} $folddir/input/atlas
    cp -l "${templates[@]}" $folddir/input/template
    cp -l "${subjects[@]}" $folddir/input/subject
    (cd $folddir; mb.sh)
done
