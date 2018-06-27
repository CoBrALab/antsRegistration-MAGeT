#!/bin/bash
#Functions for various stages of mb.sh

stage_init () {
  info "Creating input/atlas input/template input/subject"
  mkdir -p input/atlas input/template input/subject input/model
}

stage_status () {
  #Status printout
  info "Found:"
  info "  $(echo ${atlases} | wc -w) atlases in input/atlas"
  info "  $(echo ${labels} | wc -w) labels per atlas in input/atlas"
  info "  $(echo ${templates} | wc -w) templates in input/template"
  info "  $(echo ${subjects} | wc -w) subjects in input/subject"
  info "  $(echo ${models} | wc -w) models in input/models"

  info "Progress:"
  info "  $(find output/transforms/atlas-template -name '*1_NL.xfm' | wc -l) of $(( $(echo ${atlases} | wc -w) * $(echo ${templates} | wc -w) )) atlas-template registrations completed"
  info "  $(find output/transforms/template-subject -name '*1_NL.xfm' | wc -l) of $(( $(echo ${templates} | wc -w) * $(echo ${subjects} | wc -w) - $(echo ${templates} | wc -w) )) template-subject registrations completed"
  info "  $(find output/labels/candidates -type f | wc -l) of $(( $(echo ${atlases} | wc -w) * $(echo ${templates} | wc -w) * $(echo ${subjects} | wc -w) * $(echo ${labels} | wc -w) )) resample labels completed"
  info "  $(ls output/labels/majorityvote | wc -l) of $(( $(echo ${subjects} | wc -w) * $(echo ${labels} | wc -w) )) voted labels completed"
  if [[ -d output/multiatlas ]]
  then
    info "  $(find output/multiatlas/labels/candidates -type f | wc -l) of $(( $(echo ${atlases} | wc -w) * $(echo ${templates} | wc -w) * $(echo ${labels} | wc -w) )) multiatlas resample labels completed"
    info "  $(ls output/multiatlas/labels/majorityvote | wc -l) of $(( $(echo ${templates} | wc -w) * $(echo ${labels} | wc -w) )) multiatlas voted labels completed"
  fi
}

stage_estimate () {
    #Function estimates the memory requirements for doing registrations based on
    #empircally fit equation memoryGB = a * fixed_voxels + b * moving_voxels + c
    local a=5.454998e-07
    local b=6.458353e-08
    local c=1.305710e-01

    info "Checking Resolution of First Atlas"
    local atlas_voxels=$(( $(PrintHeader $(ls -LS ${atlases} | head -1) 2 | sed 's/x/\*/g') ))
    info "  Found ${atlas_voxels} voxels"
    info "Checking Resolution of First Template"
    local template_voxels=$(( $(PrintHeader $(ls -LS ${templates} | head -1) 2 | sed 's/x/\*/g') ))
    info "  Found ${template_voxels} voxels"
    info "Checking Resolution of First Subject"
    local subject_voxels=$(( $(PrintHeader $(ls -LS ${subjects} | head -1) 2 | sed 's/x/\*/g') ))
    info "  Found ${subject_voxels} voxels"

    notice "MAGeTbrain estimates walltime and memory based on files with the largest file size, if some files are uncompressed, this estimate may be incorrect"

    local atlas_template_memory
    atlas_template_memory=$(python -c "import math; print(max(1, int(math.ceil((${a} *  ${template_voxels} + ${b} * ${atlas_voxels} + ${c}) * ${__memory_scaling_factor}))))")
    local template_subject_memory
    template_subject_memory=$(python -c "import math; print(max(1, int(math.ceil((${a} *  ${subject_voxels} + ${b} * ${template_voxels} + ${c}) * ${__memory_scaling_factor}))))")

    #Estimate walltime from empircally fit equation: seconds = d * fixed_voxels + e * moving_voxels + f
    local d=3.763172e-04
    local e=3.871282e-06
    local f=4.223281e+03
    local atlas_template_walltime_seconds
    atlas_template_walltime_seconds=$(python -c "import math; print(int(math.ceil((${d} *  ${template_voxels} + ${e} * ${atlas_voxels} + ${f}) * ${__walltime_scaling_factor})))")
    local template_subject_walltime_seconds
    template_subject_walltime_seconds=$(python -c "import math; print(int(math.ceil((${d} *  ${subject_voxels} + ${e} * ${template_voxels} + ${f}) * ${__walltime_scaling_factor})))")

    #A little bit of special casing for SciNet
    if [[ $(printenv) =~ niagara ]]
    then
        __qbatch_atlas_template_opts="--walltime $(( atlas_template_walltime_seconds * 8 * ${QBATCH_CORES:-${QBATCH_PPJ:-1}} * ${QBATCH_CHUNKSIZE:-${QBATCH_PPJ:-1}} / ${QBATCH_PPJ:-1} / 60 ))"
        __qbatch_template_subject_opts="--walltime $(( template_subject_walltime_seconds * 8 * ${QBATCH_CORES:-${QBATCH_PPJ:-1}} * ${QBATCH_CHUNKSIZE:-${QBATCH_PPJ:-1}} / ${QBATCH_PPJ:-1} / 60 ))"
    else
        # Assume QBATCH variables are set properly, scale memory and walltime according to QBATCH specifications
        __qbatch_atlas_template_opts="--mem $(( atlas_template_memory * ${QBATCH_CORES:-${QBATCH_PPJ:-1}} ))G --walltime $(( atlas_template_walltime_seconds * 8  * ${QBATCH_CHUNKSIZE:-${QBATCH_PPJ:-1}} * ${QBATCH_CORES:-${QBATCH_PPJ:-1}} / ${QBATCH_PPJ:-1} ))"
        __qbatch_template_subject_opts="--mem $(( template_subject_memory * ${QBATCH_CORES:-${QBATCH_PPJ:-1}} ))G  --walltime $(( template_subject_walltime_seconds * 8  * ${QBATCH_CHUNKSIZE:-${QBATCH_PPJ:-1}} * ${QBATCH_CORES:-${QBATCH_PPJ:-1}} / ${QBATCH_PPJ:-1} ))"
    fi
}

stage_register_atlas_template () {
    #Atlas to template registration
    info "Computing Atlas to Template Registrations"
    for template in ${templates}
    do
        local templatename=$(basename ${template})
        for atlas in ${atlases}
        do
            local atlasname=$(basename ${atlas})
            if [[ ! -s output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}1_NL.xfm ]]
            then
                if [[ -n ${__mb_label_masking} ]]
                then
                    debug ${regcommand} ${atlas} ${template} output/transforms/atlas-template/${templatename} $(echo ${atlas}  | sed -r 's/(.mnc|.nii|.nii.gz|.nrrd)//g' | sed 's/_t1//g')_label*
                    echo ${regcommand} ${atlas} ${template} output/transforms/atlas-template/${templatename} $(echo ${atlas}  | sed -r 's/(.mnc|.nii|.nii.gz|.nrrd)//g' | sed 's/_t1//g')_label*
                else
                    debug ${regcommand} ${atlas} ${template} output/transforms/atlas-template/${templatename}
                    echo ${regcommand} ${atlas} ${template} output/transforms/atlas-template/${templatename}
                fi
            fi
        done > output/jobscripts/${__datetime}-mb_register_atlas_template-${templatename}
        debug qbatch ${dryrun} --logdir 'output/logs' ${__qbatch_atlas_template_opts} output/jobscripts/${__datetime}-mb_register_atlas_template-${templatename}
        qbatch ${dryrun} --logdir 'output/logs' ${__qbatch_atlas_template_opts} output/jobscripts/${__datetime}-mb_register_atlas_template-${templatename}
    done
}

stage_multiatlas_resample () {
    debug "Setting up Multiatlas/Template Output Directories"
    mkdir -p output/multiatlas/labels/candidates
    for template in ${templates}
    do
        mkdir -p output/multiatlas/labels/candidates/$(basename ${template})
    done
    info "Computing Multiatlas/Template Label Resamples"
    for template in ${templates}
    do
        local templatename=$(basename ${template})
        for atlas in ${atlases}
        do
            local atlasname=$(basename ${atlas})
            for label in ${labels}
            do
                local labelname=$(basename ${label})
                if [[ ! -s output/multiatlas/labels/candidates/${templatename}/${atlasname}-${templatename}-${labelname} ]]
                then
                    debug mb_multiatlas_resample.sh ${labelname} ${atlas} ${template}
                    echo mb_multiatlas_resample.sh ${labelname} ${atlas} ${template}
                fi
            done
        done
    done > output/jobscripts/${__datetime}-mb-multiatlas_resample
    debug qbatch ${dryrun} --logdir 'output/logs' -j 4 -c 1000 --depend "${__datetime}-mb_register_atlas_template*" --walltime 4:00:00 output/jobscripts/${__datetime}-mb-multiatlas_resample
    qbatch ${dryrun} --logdir 'output/logs' -j 4 -c 1000 --depend "${__datetime}-mb_register_atlas_template*" --walltime 4:00:00 output/jobscripts/${__datetime}-mb-multiatlas_resample
}

stage_multiatlas_vote () {
    info "Computing Multiatlas/Template Votes"
    mkdir -p output/multiatlas/labels/majorityvote
    for template in ${templates}
    do
        local templatename=$(basename ${template})
        for label in ${labels}
        do
            local labelname=$(basename ${label})
            if [[ ! -s output/multiatlas/labels/majorityvote/${templatename}_$(echo ${labelname} | sed -r 's/(.mnc|.nii|.nii.gz|.nrrd)//g')$(echo ${templatename} | grep -i -o -E '(.mnc|.nii|.nii.gz|.nrrd)') ]]
            then
                local majorityvotingcmd="mb_multiatlas_vote.sh ${labelname} ${template}"
                for atlas in ${atlases}
                do
                    local atlasname=$(basename ${atlas})
                    majorityvotingcmd+=" output/multiatlas/labels/candidates/${templatename}/${atlasname}-${templatename}-${labelname}"
                done
                echo """${majorityvotingcmd} && \
        ConvertImage 3 output/multiatlas/labels/majorityvote/${templatename}_${label} /tmp/${templatename}_${label} 1 && \
                    mv /tmp/${templatename}_${label} output/multiatlas/labels/majorityvote/${templatename}_${label}"""
            fi
        done
    done > output/jobscripts/${__datetime}-mb-multiatlas_vote
    debug qbatch ${dryrun} --logdir 'output/logs' -j 2 -c 100 --depend "${__datetime}-mb-multiatlas_resample*" --walltime 4:00:00 output/jobscripts/${__datetime}-mb-multiatlas_vote
    qbatch ${dryrun} --logdir 'output/logs' -j 2 -c 100 --depend "${__datetime}-mb-multiatlas_resample*" --walltime 4:00:00 output/jobscripts/${__datetime}-mb-multiatlas_vote
}


stage_register_template_subject () {
    #Template to subject registration
    info "Computing Template to Subject Registrations"
    for subject in ${subjects}
    do
        local subjectname=$(basename ${subject})
        for template in ${templates}
        do
            local templatename=$(basename ${template})
            #If subject and template name are the same, skip the registration step since it should be identity
            if [[ (! -s output/transforms/template-subject/${subjectname}/${templatename}-${subjectname}1_NL.xfm) && (${subjectname} != "${templatename}") ]]
            then
                debug ${regcommand} ${template} ${subject} output/transforms/template-subject/${subjectname}
                echo ${regcommand} ${template} ${subject} output/transforms/template-subject/${subjectname}
            fi
        done > output/jobscripts/${__datetime}-mb_register_template_subject-${subjectname}
        debug qbatch ${dryrun} --logdir 'output/logs' ${__qbatch_template_subject_opts} output/jobscripts/${__datetime}-mb_register_template_subject-${subjectname}
        qbatch ${dryrun} --logdir 'output/logs' ${__qbatch_template_subject_opts} output/jobscripts/${__datetime}-mb_register_template_subject-${subjectname}
    done
}

stage_resample () {
    #Resample candidate labels
    info "Computing Label Resamples"
    for subject in ${subjects}
    do
        local subjectname=$(basename ${subject})
        for template in ${templates}
        do
            local templatename=$(basename ${template})
            for atlas in ${atlases}
            do
                local atlasname=$(basename ${atlas})
                for label in ${labels}
                do
                    local labelname=$(basename ${label})
                    if [[ ! -s output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-${labelname} ]]
                    then
                        debug mb_resample.sh ${labelname} ${atlas} ${template} ${subject}
                        echo mb_resample.sh ${labelname} ${atlas} ${template} ${subject}
                    fi
                done
            done
        done > output/jobscripts/${__datetime}-mb_resample-${subjectname}
        debug qbatch ${dryrun} --logdir 'output/logs' -j 2 -c 1000 --depend "${__datetime}-mb_register_atlas_template*" --depend "${__datetime}-mb_register_template_subject-${subjectname}*" --walltime 6:00:00 output/jobscripts/${__datetime}-mb_resample-${subjectname}
        qbatch ${dryrun} --logdir 'output/logs' -j 2 -c 1000 --depend "${__datetime}-mb_register_atlas_template*" --depend "${__datetime}-mb_register_template_subject-${subjectname}*" --walltime 6:00:00 output/jobscripts/${__datetime}-mb_resample-${subjectname}
    done
}

stage_vote () {
    #Voting
    info "Computing Votes"
    for subject in ${subjects}
    do
        local subjectname=$(basename ${subject})
        for label in ${labels}
        do
            local labelname=$(basename ${label})
            if [[ ! -s output/labels/majorityvote/${subjectname}_$(echo ${labelname} | sed -r 's/(.mnc|.nii|.nii.gz|.nrrd)//g')$(echo ${subjectname} | grep -i -o -E '(.mnc|.nii|.nii.gz|.nrrd)') ]]
            then
                local majorityvotingcmd="mb_vote.sh ${labelname} ${subject}"
                for atlas in ${atlases}
                do
                    local atlasname=$(basename ${atlas})
                    for template in ${templates}
                    do
                        local templatename=$(basename ${template})
                        majorityvotingcmd+=" output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-${labelname}"
                    done
                done
                debug ${majorityvotingcmd}
                echo ${majorityvotingcmd}
            fi
        done > output/jobscripts/${__datetime}-mb_vote-${subjectname}
        debug qbatch ${dryrun} --logdir 'output/logs' -j 2 -c 1000 --depend "${__datetime}-mb_resample-${subjectname}*" --walltime 0:30:00 output/jobscripts/${__datetime}-mb_vote-${subjectname}
        qbatch ${dryrun} --logdir 'output/logs' -j 2 -c 1000 --depend "${__datetime}-mb_resample-${subjectname}*" --walltime 0:30:00 output/jobscripts/${__datetime}-mb_vote-${subjectname}
    done
}

stage_qc () {
    #Voting
    info "Computing QC Images"
    mkdir -p output/labels/QC
    for subject in ${subjects}
    do
        local subjectname=$(basename ${subject})
        for label in ${labels}
        do
            local labelname=$(basename ${label})
            if [[ ! -s output/labels/QC/${subjectname}_${labelname}.jpg ]]
            then
                echo mb_qc.sh ${subject} output/labels/majorityvote/${subjectname}_$(echo ${labelname} | sed -r 's/(.mnc|.nii|.nii.gz|.nrrd)//g')$(echo ${subjectname} | grep -i -o -E '(.mnc|.nii|.nii.gz|.nrrd)') \
                    output/labels/QC
                debug mb_qc.sh ${subject} output/labels/majorityvote/${subjectname}_$(echo ${labelname} | sed -r 's/(.mnc|.nii|.nii.gz|.nrrd)//g')$(echo ${subjectname} | grep -i -o -E '(.mnc|.nii|.nii.gz|.nrrd)') \
                    output/labels/QC
            fi
        done > output/jobscripts/${__datetime}-mb_qc-${subjectname}
        debug qbatch ${dryrun} --logdir 'output/logs' -j 1 -c 1000 --depend ${__datetime}-mb_vote-${subjectname} --walltime 0:30:00 ${__datetime}-mb_qc-${subjectname}
        qbatch ${dryrun} --logdir 'output/logs' -j 1 -c 1000 --depend ${__datetime}-mb_vote-${subjectname} --walltime 0:30:00 ${__datetime}-mb_qc-${subjectname}
    done
}

stage_cleanup () {
    #Tar and delete intermediate files
    info "Calculating tarring and delete cleanup jobs"

cat <<- EOF > output/jobscripts/${__datetime}-mb_cleanup
tar -cvf output/transforms/atlas-template.tar.gz output/transforms/atlas-template && rm -rf output/transforms/atlas-template
tar -cvf output/transforms/template-subject.tar.gz output/transforms/template-subject && rm -rf output/transforms/template-subject
tar -cvf output/labels/candidates.tar.gz output/labels/candidates && rm -rf output/labels/candidates
if [[ -d output/multiatlas/labels/candidates ]]; then tar -cvf output/labels/candidates.tar.gz output/multiatlas/labels/candidates && rm -rf output/multiatlas/labels/candidates; fi
EOF
    debug qbatch ${dryrun} --logdir 'output/logs' --walltime 8:00:00 --depend "${__datetime}-mb*" output/jobscripts/${__datetime}-mb_cleanup
    qbatch ${dryrun} --logdir 'output/logs' --walltime 8:00:00 --depend "${__datetime}-mb*" output/jobscripts/${__datetime}-mb_cleanup
}
