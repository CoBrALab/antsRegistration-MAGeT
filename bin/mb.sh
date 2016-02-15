#!/bin/bash
#Make the script stop immediately with errors
export LC_ALL=C
set -e

#All jobs are prefixed with a date-time in ISO format(to the minute) so you can submit multiple jobs at once
datetime=$(date -u +%F-%R:%S)

if [[ ! (-e input/atlas && -e input/template && -e input/subject )]]
then
    echo "Error, input directories not found"
    exit 1
fi

#Collect a list of atlas/template/subject files, must be named _t1.(nii,nii.gz,mnc, hdr/img)
atlases=$(find input/atlas -maxdepth 1 -name '*_t1.mnc' -o -name '*_t1.nii' -o -name '*_t1.nii.gz')
templates=$(find input/template -maxdepth 1 -name '*_t1.mnc' -o -name '*_t1.nii' -o -name '*_t1.nii.gz')
subjects=$(find input/subject -maxdepth 1 -name '*_t1.mnc' -o -name '*_t1.nii' -o -name '*_t1.nii.gz')
if [[ -e input/models ]]
then
models=$(find input/model -maxdepth 1 -name '*_t1.mnc' -o -name '*_t1.nii' -o -name '*_t1.nii.gz')
fi

#Labels are figured out by looking at only the first atlas, and substituting t1 for label*
labels=$(ls $(echo $atlases | cut -d " " -f 1 | sed 's/t1/label\*/g') | sed 's/input.*label/label/g')

#Alternative registration commands can be specified
#Must accept $movingfile $fixedfile $outputprefix
regcommand="mb_register.sh"
#regcommand="mb_registerBSplineSyN.sh"

#Create directories
mkdir -p .scripts
mkdir -p output/transforms/atlas-template
mkdir -p output/transforms/template-subject
mkdir -p output/labels/candidates
mkdir -p output/labels/majorityvote
mkdir -p logs
#mkdir -p output/labels/STAPLE
#mkdir -p output/labels/jointfusion

#Status printout
echo "Found $(echo $atlases | wc -w) atlases in input/atlas"
echo "Found $(echo $labels | wc -w) labels in  input/atlas"
echo "Found $(echo $templates | wc -w) templates in input/template"
echo "Found $(echo $subjects | wc -w) subjects in input/subject"
echo "Found $(echo $models | wc -w) models in input/models"

echo "$(ls output/labels/majorityvote | wc -l) of $(expr $(echo $subjects | wc -w) \* $(echo $labels | wc -w)) labels completed"

if [[ $(stat -L --printf="%s" $(echo $atlases | cut -d " " -f 1)) -gt 200000000 ]]
then
    echo "High resolution atlas detected, atlas-template registrations will be submitted to 32GB nodes"
    hires=1
fi


if [[ -n $1 ]]
then
    echo Status only requested, terminating
    exit 0
fi

#Directory Setup
for subject in $subjects
do
    mkdir -p output/labels/candidates/$(basename $subject)
    mkdir -p output/transforms/template-subject/$(basename $subject)
done

for template in $templates
do
    mkdir -p output/transforms/atlas-template/$(basename $template)
done


#Atlas to template registration
echo "Computing Atlas to Template Registrations"
for template in $templates
do
  templatename=$(basename $template)
    for atlas in $atlases
    do
        atlasname=$(basename $atlas)
        if [[ ! -s output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}0_GenericAffine.xfm ]]
        then
            echo $regcommand $atlas $template output/transforms/atlas-template/${templatename} >> .scripts/${datetime}-mb_register_atlas_template-${templatename}
        fi
    done
    if [[ -s .scripts/${datetime}-mb_register_atlas_template-${templatename} ]]
    then
        if [[ -n $hires ]]
        then
        ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=5 qbatch --highmem -j 2 -c 10 .scripts/${datetime}-mb_register_atlas_template-${templatename} -- -l walltime=24:00:00 &
        else
        ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=3 qbatch -j 4 -c 4 .scripts/${datetime}-mb_register_atlas_template-${templatename} -- -l walltime=12:00:00 &
        fi
    fi
done

#Template to subject registration
echo "Computing Template to Subject Registrations"
for subject in $subjects
do
    subjectname=$(basename $subject)
    for template in $templates
    do
        templatename=$(basename $template)
        #If subject and template name are the same, skip the registration step since it should be identity
        if [[ (! -s output/transforms/template-subject/${subjectname}/${templatename}-${subjectname}0_GenericAffine.xfm) && (${subjectname} != ${templatename}) ]]
        then
            echo $regcommand $template $subject output/transforms/template-subject/${subjectname} >> .scripts/${datetime}-mb_register_template_subject-${subjectname}
        fi
    done
    if [[ -s .scripts/${datetime}-mb_register_template_subject-${subjectname} ]]
    then
        ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=5 qbatch -j 2 -c 10 .scripts/${datetime}-mb_register_template_subject-${subjectname} -- -l walltime=12:00:00 &
    fi
done


#Resample candidate labels
echo "Computing Label Resamples"
for subject in $subjects
do
    subjectname=$(basename $subject)
    for template in $templates
    do
        templatename=$(basename $template)
        for atlas in $atlases
        do
            atlasname=$(basename $atlas)
            for label in $labels
            do
                labelname=$(basename $label)
                if [[ (! -s output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-$labelname) && (${subjectname} != ${templatename}) ]]
                then
                    #Transforms are applied like a stack (or Matrix algebra) so last is applied first, this goes atlas->template->subject
                    echo """ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=3 antsApplyTransforms --interpolation MultiLabel -r $subject -i $(echo $atlas | sed -E "s/t1\.(nii|nii\.gz|mnc)/${label}/g") \
                            -o output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-$labelname \
                            -t output/transforms/template-subject//${subjectname}/${templatename}-${subjectname}1_NL.xfm \
                            -t output/transforms/template-subject/${subjectname}/${templatename}-${subjectname}0_GenericAffine.xfm \
                            -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}1_NL.xfm \
                            -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}0_GenericAffine.xfm; \
                        ConvertImagePixelType output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-$labelname \
                            /tmp/${atlasname}-${templatename}-${subjectname}-$labelname 1; \
                        mv /tmp/${atlasname}-${templatename}-${subjectname}-$labelname \
                            output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-$labelname"""
                elif [[ ! -s output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-$labelname ]]
                then
                    #In the case the filename of subject and template are the same, assume identical subjects, skip the registration
                    echo """ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=3 antsApplyTransforms --interpolation MultiLabel -r $subject -i $(echo $atlas | sed -E "s/t1\.(nii|nii\.gz|mnc)/${label}/g") \
                            -o output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-$labelname \
                            -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}1_NL.xfm \
                            -t output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}0_GenericAffine.xfm; \
                        ConvertImagePixelType output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-$labelname \
                            /tmp/${atlasname}-${templatename}-${subjectname}-$labelname 1; \
                        mv /tmp/${atlasname}-${templatename}-${subjectname}-$labelname \
                            output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-$labelname"""
                fi
            done
        done
    done >> .scripts/${datetime}-mb_resample-${subjectname}
    #Resamples seem to be very efficient so we need to group more of them together
    if [[ -s .scripts/${datetime}-mb_resample-${subjectname} ]]
    then
        qbatch -j 4 -c 1000 --afterok_pattern "${datetime}-mb_register_atlas_template*" \
            --afterok_pattern "${datetime}-mb_register_template_subject-${subjectname}*" .scripts/${datetime}-mb_resample-${subjectname} -- -l walltime=12:00:00 &
    fi
done

#Voting
for subject in $subjects
do
    subjectname=$(basename $subject)
    for label in $labels
    do
        labelname=$(basename $label)
        if [[ ! -s output/labels/majorityvote/${subjectname}_$label ]]
        then
            majorityvotingcmd="ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=5 ImageMath 3 output/labels/majorityvote/${subjectname}_$label MajorityVoting"
            for atlas in $atlases
            do
                atlasname=$(basename $atlas)
                for template in $templates
                do
                    templatename=$(basename $template)
                    majorityvotingcmd+=" output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-$labelname"
                done
            done
        echo """$majorityvotingcmd; \
            ConvertImagePixelType output/labels/majorityvote/${subjectname}_$label /tmp/${subjectname}_$label 1; \
            mv /tmp/${subjectname}_$label output/labels/majorityvote/${subjectname}_$label""" \
             >> .scripts/${datetime}-mb_vote-${subjectname}
        fi
    done
    if [[ -s .scripts/${datetime}-mb_vote-${subjectname} ]]
    then
        qbatch -j 2 -c 100 --afterok_pattern "${datetime}-mb_resample-${subjectname}*" .scripts/${datetime}-mb_vote-${subjectname} -- -l walltime=4:00:00 &
    fi
done
