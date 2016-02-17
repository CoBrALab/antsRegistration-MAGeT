#!/bin/bash -e
#Make the script stop immediately with errors
export LC_ALL=C

echo "Warning, this is not MAGeTbrain, this is a simple multi-atlas fusion version"
echo "Use this for doing template selection or for validation work only"
echo "This script does not do any registrations"

#All jobs are prefixed with a date-time in ISO format(to the minute) so you can submit multiple jobs at once
datetime=$(date -u +%F-%R:%S)

if [[ ! (-e input/atlas && -e input/template )]]
then
    echo "Error, input directories not found"
    exit 1
fi

#Collect a list of atlas/template/subject files, must be named _t1.(nii,nii.gz,mnc, hdr/img)
atlases=$(find input/atlas -maxdepth 1 -name '*_t1.mnc' -o -name '*_t1.nii' -o -name '*_t1.nii.gz')
templates=$(find input/template -maxdepth 1 -name '*_t1.mnc' -o -name '*_t1.nii' -o -name '*_t1.nii.gz')
if [[ -e input/models ]]
then
models=$(find input/model -maxdepth 1 -name '*_t1.mnc' -o -name '*_t1.nii' -o -name '*_t1.nii.gz')
fi

#Labels are figured out by looking at only the first atlas, and substituting t1 for label*
labels=$(ls $(echo $atlases | cut -d " " -f 1 | sed 's/t1/label\*/g') | sed 's/input.*label/label/g')

#Create directories
mkdir -p .scripts
mkdir -p output/transforms/atlas-template
mkdir -p output/multiatlas/labels/candidates
mkdir -p output/multiatlas/labels/majorityvote
mkdir -p logs
#mkdir -p output/labels/STAPLE
#mkdir -p output/labels/jointfusion

#Status printout
echo "Found $(echo $atlases | wc -w) atlases in input/atlas"
echo "Found $(echo $labels | wc -w) labels in  input/atlas"
echo "Found $(echo $templates | wc -w) templates in input/template"
echo "Found $(echo $models | wc -w) models in input/models"

echo "$(ls output/multiatlas/labels/majorityvote | wc -l) of $(expr $(echo $templates | wc -w) \* $(echo $labels | wc -w)) labels completed"

if [[ -n $1 ]]
then
    echo Status only requested, terminating
    exit 0
fi

#Directory Setup
for template in $templates
do
    mkdir -p output/multiatlas/labels/candidates/$(basename $template)
done

#Resample candidate labels
echo "Computing Label Resamples"
for template in $templates
do
    templatename=$(basename $template)
    for atlas in $atlases
    do
        atlasname=$(basename $atlas)
        for label in $labels
        do
            labelname=$(basename $label)
            if [[ ! -s output/multiatlas/labels/candidates/${templatename}/${atlasname}-${templatename}-$labelname ]]
            then
                echo """antsApplyTransforms -d 3 --interpolation MultiLabel -r $template -i $(echo $atlas | sed -E "s/t1\.(nii|nii\.gz|mnc)/${label}/g") \
                        -o output/multiatlas/labels/candidates/${templatename}/${atlasname}-${templatename}-$labelname \
                        -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}1_NL.xfm \
                        -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}0_GenericAffine.xfm && \
                    ConvertImage output/multiatlas/labels/candidates/${templatename}/${atlasname}-${templatename}-$labelname \
                        /tmp/${atlasname}-${templatename}-$labelname 1 && \
                    mv /tmp/${atlasname}-${templatename}-$labelname \
                        output/multiatlas/labels/candidates/${templatename}/${atlasname}-${templatename}-$labelname"""
            fi
        done
    done | ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=3 qbatch -j 4 -c 1000 --jobname ${datetime}-mb-multiatlas_resample-${templatename} - -- "#PBS -l walltime=12:00:00"
done

#Voting
for template in $templates
do
    templatename=$(basename $template)
    for label in $labels
    do
        labelname=$(basename $label)
        if [[ ! -s output/multiatlas/labels/majorityvote/${templatename}_$label ]]
        then
            majorityvotingcmd="ImageMath 3 output/multiatlas/labels/majorityvote/${templatename}_$label MajorityVoting"
            for atlas in $atlases
            do
                atlasname=$(basename $atlas)
                majorityvotingcmd+=" output/multiatlas/labels/candidates/${templatename}/${atlasname}-${templatename}-$labelname"
            done
        echo """$majorityvotingcmd && \
            ConvertImage output/multiatlas/labels/majorityvote/${templatename}_$label /tmp/${templatename}_$label 1 && \
            mv /tmp/${templatename}_$label output/multiatlas/labels/majorityvote/${templatename}_$label"""
        fi
    done | ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=5 qbatch -j 2 -c 100 --afterok_pattern "${datetime}-mb-multiatlas_resample-${templatename}*" --jobname ${datetime}-mb-multiatlas_vote-${templatename} - -- "#PBS -l walltime=4:00:00"
done
