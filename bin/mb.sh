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
done

#Atlas to template registration
for template in $templates
do
    for atlas in $atlases
    do
        if [[ ! -s output/transforms/atlas-template/$(basename $atlas)-$(basename $template)0_GenericAffine.xfm ]]
        then
            echo $regcommand $atlas $template output/transforms/atlas-template >> .scripts/${datetime}-mb_register_atlas_template-$(basename $template)
        fi
    done
    if [[ -s .scripts/${datetime}-mb_register_atlas_template-$(basename $template) ]]
    then
        if [[ -n $hires ]]
        then
        ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=5 qbatch --highmem --processes=2 .scripts/${datetime}-mb_register_atlas_template-$(basename $template) 10 24:00:00
        else
        ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=3 qbatch --processes=4 .scripts/${datetime}-mb_register_atlas_template-$(basename $template) 4 3:00:00
        fi
    fi
done

#Template to subject registration
for subject in $subjects
do
    for template in $templates
    do
        #If subject and template name are the same, skip the registration step since it should be identity
        if [[ (! -s output/transforms/template-subject/$(basename $template)-$(basename $subject)0_GenericAffine.xfm) && ($(basename $subject) != $(basename $template)) ]]
        then
            echo $regcommand $template $subject output/transforms/template-subject >> .scripts/${datetime}-mb_register_template_subject-$(basename $subject)
        fi
    done
    if [[ -s .scripts/${datetime}-mb_register_template_subject-$(basename $subject) ]]
    then
        ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=4 qbatch --processes=2 .scripts/${datetime}-mb_register_template_subject-$(basename $subject) 10 12:00:00
    fi
done

#Resample candidate labels
for subject in $subjects
do
    for template in $templates
    do
        for atlas in $atlases
        do
            for label in $labels
            do
                if [[ (! -s output/labels/candidates/$(basename $subject)/$(basename $atlas)-$(basename $template)-$(basename $subject)-$(basename $label)) && ($(basename $subject) != $(basename $template)) ]]
                then
                    #Transforms are applied like a stack (or Matrix algebra) so last is applied first, this goes atlas->template->subject
                    echo """antsApplyTransforms --interpolation MultiLabel -r $subject -i $(echo $atlas | sed -E "s/t1\.(nii|nii\.gz|mnc)/${label}/g") \
                            -o output/labels/candidates/$(basename $subject)/$(basename $atlas)-$(basename $template)-$(basename $subject)-$(basename $label) \
                            -t output/transforms/template-subject/$(basename $template)-$(basename $subject)1_NL.xfm \
                            -t output/transforms/template-subject/$(basename $template)-$(basename $subject)0_GenericAffine.xfm \
                            -t output/transforms/atlas-template/$(basename $atlas)-$(basename $template)1_NL.xfm \
                            -t output/transforms/atlas-template/$(basename $atlas)-$(basename $template)0_GenericAffine.xfm; \
                        ConvertImagePixelType output/labels/candidates/$(basename $subject)/$(basename $atlas)-$(basename $template)-$(basename $subject)-$(basename $label) \
                            /tmp/$(basename $atlas)-$(basename $template)-$(basename $subject)-$(basename $label) 1; \
                        mv /tmp/$(basename $atlas)-$(basename $template)-$(basename $subject)-$(basename $label) \
                            output/labels/candidates/$(basename $subject)/$(basename $atlas)-$(basename $template)-$(basename $subject)-$(basename $label)""" \
                        >> .scripts/${datetime}-mb_resample-$(basename $subject)
                elif [[ ! -s output/labels/candidates/$(basename $subject)/$(basename $atlas)-$(basename $template)-$(basename $subject)-$(basename $label) ]]
                then
                    #In the case the filename of subject and template are the same, assume identical subjects, skip the registration
                    echo """antsApplyTransforms --interpolation MultiLabel -r $subject -i $(echo $atlas | sed -E "s/t1\.(nii|nii\.gz|mnc)/${label}/g") \
                            -o output/labels/candidates/$(basename $subject)/$(basename $atlas)-$(basename $template)-$(basename $subject)-$(basename $label) \
                            -t output/transforms/atlas-template/$(basename $atlas)-$(basename $template)1_NL.xfm \
                            -t output/transforms/atlas-template/$(basename $atlas)-$(basename $template)0_GenericAffine.xfm; \
                        ConvertImagePixelType output/labels/candidates/$(basename $subject)/$(basename $atlas)-$(basename $template)-$(basename $subject)-$(basename $label) \
                            /tmp/$(basename $atlas)-$(basename $template)-$(basename $subject)-$(basename $label) 1; \
                        mv /tmp/$(basename $atlas)-$(basename $template)-$(basename $subject)-$(basename $label) \
                            output/labels/candidates/$(basename $subject)/$(basename $atlas)-$(basename $template)-$(basename $subject)-$(basename $label)""" \
                        >> .scripts/${datetime}-mb_resample-$(basename $subject)
                fi
            done
        done
    done
    #Resamples seem to be very efficient so we need to group more of them together
    if [[ -s .scripts/${datetime}-mb_resample-$(basename $subject) ]]
    then
        qbatch --processes 4 --afterok_pattern "${datetime}-mb_register_atlas_template*" \
            --afterok_pattern "${datetime}-mb_register_template_subject-$(basename $subject)*" .scripts/${datetime}-mb_resample-$(basename $subject) 1000 4:00:00
    fi
done

#Voting
for subject in $subjects
do
    for label in $labels
    do
        if [[ ! -s output/labels/majorityvote/$(basename $subject)_$label ]]
        then
            majorityvotingcmd="ImageMath 3 output/labels/majorityvote/$(basename $subject)_$label MajorityVoting"
            for atlas in $atlases
            do
                for template in $templates
                do
                    majorityvotingcmd+=" output/labels/candidates/$(basename $subject)/$(basename $atlas)-$(basename $template)-$(basename $subject)-$(basename $label)"
                done
            done
        echo """$majorityvotingcmd; \
            ConvertImagePixelType output/labels/majorityvote/$(basename $subject)_$label /tmp/$(basename $subject)_$label 1; \
            mv /tmp/$(basename $subject)_$label output/labels/majorityvote/$(basename $subject)_$label""" \
             >> .scripts/${datetime}-mb_vote-$(basename $subject)
        fi
    done
    if [[ -s .scripts/${datetime}-mb_vote-$(basename $subject) ]]
    then
        qbatch --processes 2 --afterok_pattern "${datetime}-mb_resample-$(basename $subject)*" .scripts/${datetime}-mb_vote-$(basename $subject) 100 0:30:00
    fi
done
