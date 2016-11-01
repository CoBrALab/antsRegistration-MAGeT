#Functions for various stages of mb.sh

stage_init () {
  info "Creating input/atlas input/template input/subject"
  mkdir -p input/atlas input/template input/subject input/model
}

stage_estimate () {
  #Function estimates the memory requirements for doing registrations based on
  #empircally fit equation memoryGB = a * fixed_voxels + b * moving_voxels + c
  local a=6.820853e-07
  local b=5.455959e-08
  local c=1.364185e-01

  scaling_factor=${arg_f}

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

  local atlas_template_memory=$(python -c "import math; print(max(1, int(math.ceil((${a} *  ${template_voxels} + ${b} * ${atlas_voxels} + ${c}) * ${scaling_factor}))))")
  local template_subject_memory=$(python -c "import math; print(max(1, int(math.ceil((${a} *  ${subject_voxels} + ${b} * ${template_voxels} + ${c}) * ${scaling_factor}))))")

  #Estimate walltime from empircally fit equation: seconds = d * fixed_voxels + e * moving_voxels + f
  local d=9.431370e-04
  local e=5.159085e-06
  local f=3.119656e+02
  local atlas_template_walltime_seconds=$(python -c "import math; print(int(math.ceil((${d} *  ${template_voxels} + ${e} * ${atlas_voxels} + ${f}) * ${scaling_factor})))")
  local template_subject_walltime_seconds=$(python -c "import math; print(int(math.ceil((${d} *  ${subject_voxels} + ${e} * ${template_voxels} + ${f}) * ${scaling_factor})))")

  #A little bit of special casing for SciNet
  if [[ $(printenv) =~ SCINET ]]
  then

    #Breakup chunks/parallel calls for scinet jobs
    if [[ ${atlas_template_memory} -gt 62 ]]
    then
      info "Submitting template jobs to 128GB nodes"
      qbatch_atlas_template_opts="--pbs-nodes-spec m128g --queue sandy --ppj 16 -c 1 -j 1 --walltime $(( ${atlas_template_walltime_seconds} / 2 ))"
    elif [[ ${atlas_template_memory} -gt 30 ]]
    then
      info "Submitting template jobs to 64GB nodes"
      qbatch_atlas_template_opts="--pbs-nodes-spec m64g --queue sandy --ppj 16 -c 1 -j 1 --walltime $(( ${atlas_template_walltime_seconds} / 2 ))"
    elif [[ ${atlas_template_memory} -gt 14 ]]
    then
      info "Submitting template jobs to 32GB nodes"
      qbatch_atlas_template_opts="--pbs-nodes-spec m32g -c 1 -j 1  --ppj 8 --walltime ${atlas_template_walltime_seconds}"
    elif [[ ${atlas_template_memory} -gt 7 ]]
    then
      info "Submitting template jobs to 16GB nodes"
      qbatch_atlas_template_opts="-c 1 -j 1 --ppj 8 --walltime ${atlas_template_walltime_seconds}"
    else
      info "Submitting template jobs to 16GB nodes, two commands in parallel"
      qbatch_atlas_template_opts="-c 2 -j 2 --ppj 8 --walltime $(( ${atlas_template_walltime_seconds} * 2 ))"
    fi

    if [[ ${template_subject_memory} -gt 62 ]]
    then
      info "Submitting subject jobs to 128GB nodes"
      qbatch_template_subject_opts="--pbs-nodes-spec m128g --queue sandy --ppj 16 -c 1 -j 1 --walltime $(( ${template_subject_walltime_seconds} / 2 ))"
    elif [[ ${template_subject_memory} -gt 30 ]]
    then
      info "Submitting subject jobs to 64GB nodes"
      qbatch_template_subject_opts="--pbs-nodes-spec m64g --queue sandy --ppj 16 -c 1 -j 1 --walltime $(( ${template_subject_walltime_seconds} / 2 ))"
    elif [[ ${template_subject_memory} -gt 14 ]]
    then
      info "Submitting subject jobs to 32GB nodes"
      qbatch_template_subject_opts="--pbs-nodes-spec m32g -c 1 -j 1 --ppj 8 --walltime ${template_subject_walltime_seconds}"
    elif [[ ${template_subject_memory} -gt 7 ]]
    then
      info "Submitting subject jobs to 16GB nodes"
      qbatch_template_subject_opts="-c 1 -j 1 --ppj 8 --walltime ${template_subject_walltime_seconds}"
    else
      info "Submitting subject jobs to 16GB nodes, two commands in parallel"
      qbatch_template_subject_opts="-c 2 -j 2 --ppj 8 --walltime  $(( ${template_subject_walltime_seconds} * 2 ))"
    fi

  else
    # Assume QBATCH variables are set properly, scale memory and walltime according to QBATCH specifications
    qbatch_atlas_template_opts="--mem $(( ${atlas_template_memory} * ${QBATCH_CORES:-${QBATCH_PPJ:-1}} ))G --walltime $(( ${atlas_template_walltime_seconds} * 8 / ${QBATCH_PPJ:-1} * ${QBATCH_CHUNKS:-${QBATCH_PPJ:-1}} / ${QBATCH_CORES:-${QBATCH_PPJ:-1}} ))"
    qbatch_template_subject_opts="--mem $(( ${template_subject_memory} * ${QBATCH_CORES:-${QBATCH_PPJ:-1}} ))G  --walltime $(( ${template_subject_walltime_seconds} * 8 / ${QBATCH_PPJ:-1} * ${QBATCH_CHUNKS:-${QBATCH_PPJ:-1}} / ${QBATCH_CORES:-${QBATCH_PPJ:-1}} ))"
  fi
}

stage_register_atlas_template () {
  #Atlas to template registration
  info "Computing Atlas to Template Registrations"
  for template in ${templates}
  do
    templatename=$(basename ${template})
    for atlas in ${atlases}
    do
      atlasname=$(basename ${atlas})
      if [[ ! -s output/transforms/atlas-template/${templatename}/${atlasname}-${templatename}0_GenericAffine.xfm ]]
      then
        debug $regcommand ${atlas} ${template} output/transforms/atlas-template/${templatename}
        echo $regcommand ${atlas} ${template} output/transforms/atlas-template/${templatename}
      fi
    done | qbatch ${dryrun} --jobname ${datetime}-mb_register_atlas_template-${templatename} ${qbatch_atlas_template_opts} -
  done
}

stage_multiatlas_resample () {
  debug "Setting up Multiatlas/Template Output Directories"
  mkdir -p output/multiatlas/labels/candidates
  mkdir -p output/multiatlas/labels/majorityvote
  for template in ${templates}
  do
    mkdir -p output/multiatlas/labels/candidates/$(basename ${template})
  done
  info "Computing Multiatlas/Template Label Resamples"
  for template in ${templates}
  do
    templatename=$(basename ${template})
    for atlas in ${atlases}
    do
      atlasname=$(basename ${atlas})
      for label in ${labels}
      do
        labelname=$(basename ${label})
        if [[ ! -s output/multiatlas/labels/candidates/${templatename}/${atlasname}-${templatename}-${labelname} ]]
        then
          debug mb_multiatlas_resample.sh ${labelname} ${atlas} ${template}
          echo mb_multiatlas_resample.sh ${labelname} ${atlas} ${template}
        fi
      done
    done
  done | qbatch ${dryrun} -j 4 -c 1000 --depend "${datetime}-mb_register_atlas_template*" --jobname ${datetime}-mb-multiatlas_resample --walltime 4:00:00 -
}

stage_multiatlas_vote () {
  info "Computing Multiatlas/Template Votes"
  for template in ${templates}
  do
    templatename=$(basename ${template})
    for label in ${labels}
    do
      labelname=$(basename ${label})
      if [[ ! -s output/multiatlas/labels/majorityvote/${templatename}_${label} ]]
      then
        majorityvotingcmd="ImageMath 3 output/multiatlas/labels/majorityvote/${templatename}_${label} MajorityVoting"
        for atlas in ${atlases}
        do
          atlasname=$(basename ${atlas})
          majorityvotingcmd+=" output/multiatlas/labels/candidates/${templatename}/${atlasname}-${templatename}-${labelname}"
        done
        echo """$majorityvotingcmd && \
        ConvertImage 3 output/multiatlas/labels/majorityvote/${templatename}_${label} /tmp/${templatename}_${label} 1 && \
        mv /tmp/${templatename}_${label} output/multiatlas/labels/majorityvote/${templatename}_${label}"""
      fi
    done
  done | qbatch ${dryrun} -j 2 -c 100 --depend "${datetime}-mb-multiatlas_resample*" --jobname ${datetime}-mb-multiatlas_vote --walltime 4:00:00 -
}


stage_register_template_subject () {
  #Template to subject registration
  info "Computing Template to Subject Registrations"
  for subject in ${subjects}
  do
    subjectname=$(basename ${subject})
    for template in ${templates}
    do
      templatename=$(basename ${template})
      #If subject and template name are the same, skip the registration step since it should be identity
      if [[ (! -s output/transforms/template-subject/${subjectname}/${templatename}-${subjectname}0_GenericAffine.xfm) && (${subjectname} != ${templatename}) ]]
      then
        debug $regcommand ${template} ${subject} output/transforms/template-subject/${subjectname}
        echo $regcommand ${template} ${subject} output/transforms/template-subject/${subjectname}
      fi
    done | qbatch ${dryrun} --jobname ${datetime}-mb_register_template_subject-${subjectname} ${qbatch_template_subject_opts} -
  done
}

stage_resample () {
  #Resample candidate labels
  info "Computing Label Resamples"
  for subject in ${subjects}
  do
    subjectname=$(basename ${subject})
    for template in ${templates}
    do
      templatename=$(basename ${template})
      for atlas in ${atlases}
      do
        atlasname=$(basename ${atlas})
        for label in ${labels}
        do
          labelname=$(basename ${label})
          if [[ ! -s output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-${labelname} ]]
          then
            debug mb_resample.sh ${labelname} ${atlas} ${template} ${subject}
            echo mb_resample.sh ${labelname} ${atlas} ${template} ${subject}
          fi
        done
      done
    done | qbatch ${dryrun} -j 2 -c 1000 --depend "${datetime}-mb_register_atlas_template*" --depend "${datetime}-mb_register_template_subject-${subjectname}*" --jobname ${datetime}-mb_resample-${subjectname} --walltime 1:00:00 -
  done
}

stage_vote () {
  #Voting
  info "Computing Votes"
  for subject in ${subjects}
  do
    subjectname=$(basename ${subject})
    for label in ${labels}
    do
      labelname=$(basename ${label})
      if [[ ! -s output/labels/majorityvote/${subjectname}_${label} ]]
      then
        majorityvotingcmd="ImageMath 3 output/labels/majorityvote/${subjectname}_${label} MajorityVoting"
        for atlas in ${atlases}
        do
          atlasname=$(basename ${atlas})
          for template in ${templates}
          do
            templatename=$(basename ${template})
            majorityvotingcmd+=" output/labels/candidates/${subjectname}/${atlasname}-${templatename}-${subjectname}-${labelname}"
          done
        done
        echo """$majorityvotingcmd && \
        ConvertImage 3 output/labels/majorityvote/${subjectname}_${label} /tmp/${subjectname}_${label} 1 && \
        mv /tmp/${subjectname}_${label} output/labels/majorityvote/${subjectname}_${label}"""
      fi
    done | qbatch ${dryrun} -j 2 -c 1000 --depend "${datetime}-mb_resample-${subjectname}*" --jobname ${datetime}-mb_vote-${subjectname} --walltime 0:30:00 -
  done
}

stage_cleanup () {
  #Tar and delete intermediate files
  info "Calculating tarring and delete cleanup jobs"
cat <<- EOF | qbatch ${dryrun} --walltime 8:00:00 --depend "${datetime}-mb*" -
tar -I pigz -cf output/transforms/atlas-template.tar.gz output/transforms/atlas-template && rm -rf output/transforms/atlas-template
tar -I pigz -cf output/transforms/template-subject.tar.gz output/transforms/template-subject && rm -rf output/transforms/template-subject
tar -I pigz -cf output/labels/candidates.tar.gz output/labels/candidates && rm -rf output/labels/candidates
if [[ -d output/multiatlas/labels/candidates ]]; then tar -I pigz -cf output/labels/candidates.tar.gz output/multiatlas/labels/candidates && rm -rf output/multiatlas/labels/candidates; fi
EOF

}
