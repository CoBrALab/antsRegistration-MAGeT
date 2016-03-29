#!/bin/bash
# Generator for multi-atlas validation of MaGeT, shamelessly stolen from ealier script
# Start by running a mb run with all inputs as atlases, templates and subjects, skip voting
# This primes the pipeline with all the possible registrations
# Then, run multiatlas_setup.sh <nfolds> <natlases>
# This shuffles the list of inputs and creates <nfolds> random samples satisftying
# <natlases>
# Afterwards links into the directory the already processed transforms and candidate labels
# Then all that is left is to run mb-multiatlas.sh in each directory to complete the voting stage

nfolds=$1
natlases=$2
origpool=(input/atlas/*t1.mnc)

#pool=(input/atlas/*t1.mnc)
origpool=(input/atlas/*t1.mnc)

i=0
for subject in "${origpool[@]}"
do
echo $subject

subjectname=$(basename $subject)
pool=( "${origpool[@]::$i}" "${origpool[@]:$((i+1))}" )

for fold in $(seq $nfolds)
do
    #Shuffle inputs in a random list using sort
    pool=($(printf "%s\n" "${pool[@]}" | sort -R))
    #Since list is now random, slice array according to numbers provided before
    atlases=("${pool[@]:0:$natlases}")
    #templates=("${pool[@]:$natlases}")

    #Setup folders for random run
    folddir=multiatlas/${natlases}atlases_fold$fold/$subjectname
    mkdir -p $folddir/input/{atlas,template}
    mkdir -p $folddir/output/multiatlas/labels/majorityvote

    #Link in precomputed transforms and candidate labels
    ln -s $(readlink -f output/transforms) $folddir/output/transforms

    #Do a trick of replacing _t1.mnc with * to allow bash expansion to include all label files
    tmp=("${atlases[@]/_t1.mnc/*}")
    cp -l ${tmp[@]} $folddir/input/atlas
    cp -l $subject $folddir/input/template
    (cd $folddir; mb-multiatlas.sh)
done
((i++))

done
