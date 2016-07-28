#Functions for various stages of mb.sh

stage_init () {
  info "Creating input/atlas input/template input/subject"
  mkdir -p input/atlas input/template input/subject input/model
}

stage_estimate () {
  #Function estimates the memory requirements for doing registrations based on
  #empircally fit equation memoryGB = a * fixed_voxels + b * moving_voxels
  local a=5.14706437212*10^-07
  local b=4.66026378400*10^-08
  #This function only checks the resolution of the first atlas, template and
  #subject

  scaling_factor=${arg_f}

  info "Checking Resolution of First Atlas"
  local atlas_voxels=$(PrintHeader $(echo ${atlases} | cut -d " " -f 1) 2 | sed 's/x/\*/g' | bc -l )
  info "  Found ${atlas_voxels} voxels"
  info "Checking Resolution of First Template"
  local template_voxels=$(PrintHeader $(echo ${templates} | cut -d " " -f 1) 2 | sed 's/x/\*/g' | bc -l )
  info "  Found ${template_voxels} voxels"
  info "Checking Resolution of First Subject"
  local subject_voxels=$(PrintHeader $(echo ${subjects} | cut -d " " -f 1) 2 | sed 's/x/\*/g' | bc -l )
  info "  Found ${subject_voxels} voxels"

  notice "MAGeTbrain makes no attempt to find the maximum resolution file, if you have mixed resolutions, make your highest resoluition file the first file"

  local atlas_template_memory=$(echo "(${a} *  ${template_voxels} + ${b} * ${atlas_voxels}) * ${scaling_factor}" | bc -l )
  local template_subject_memory=$(echo "(${a} *  ${subject_voxels} + ${b} * ${template_voxels}) * ${scaling_factor}" | bc -l )

  #Estimate walltime from empircally fit equation: seconds = d * fixed_voxels + e * moving_voxels + f
  local d=6.42823232396*10^-04
  local e=2.67264359869*10^-06
  local f=3.83604652955*10^02
  local atlas_template_walltime_seconds=$(echo "(${d} *  ${template_voxels} + ${e} * ${atlas_voxels} + ${f}) * ${scaling_factor}"  | bc -l | cut -d"." -f1)
  local template_subject_walltime_seconds=$(echo "(${d} *  ${subject_voxels} + ${e} * ${template_voxels} + ${f}) * ${scaling_factor}" | bc -l | cut -d"." -f1)

  #A little bit of special casing for SciNet, eventually need to figure out
  #rules for non-scinet systems
  if [[ $(printenv) =~ SCINET ]]
  then

    #Breakup chunks/parallel calls for scinet jobs
    if [[ $(echo "${atlas_template_memory} > 32" | bc) == 1 ]]
    then
      warning "MAGeTbrain estimates memory usage of ${atlas_template_memory} GB for atlas-template registrations"
      warning "  This memory usage is higher than the SciNet highmem nodes, you may experience failures"
      qbatch_atlas_template_opts="--highmem -c 1 -j 1 --walltime ${atlas_template_walltime_seconds}"
    elif [[ $(echo "${atlas_template_memory} > 24" | bc) == 1 ]]
    then
      qbatch_atlas_template_opts="--highmem -c 1 -j 1 --walltime ${atlas_template_walltime_seconds}"
    elif [[ $(echo "${atlas_template_memory} > 16" | bc) == 1 ]]
    then
      qbatch_atlas_template_opts="--highmem -c 2 -j 2 --walltime $(echo "${atlas_template_walltime_seconds} * 2" | bc)"
    elif [[ $(echo "${atlas_template_memory} > 8" | bc) == 1 ]]
    then
      qbatch_atlas_template_opts="-c 1 -j 1 --walltime ${atlas_template_walltime_seconds}"
    else
      qbatch_atlas_template_opts="-c 2 -j 2 --walltime $(echo "${atlas_template_walltime_seconds} * 2" | bc)"
    fi

    if [[ $(echo "${template_subject_memory} > 24" | bc) == 1 ]]
    then
      qbatch_template_subject_opts="--highmem -c 1 -j 1 --walltime ${template_subject_walltime_seconds}"
    elif [[ $(echo "${template_subject_memory} > 16" | bc) == 1 ]]
    then
      qbatch_template_subject_opts="--highmem -c 2 -j 2 --walltime $(echo "${template_subject_walltime_seconds} * 2" | bc)"
    elif [[ $(echo "${template_subject_memory} > 8" | bc) == 1 ]]
    then
      qbatch_template_subject_opts="-c 1 -j 1 --walltime ${template_subject_walltime_seconds}"
    else
      qbatch_template_subject_opts="-c 2 -j 2 --walltime  $(echo "${template_subject_walltime_seconds} * 2" | bc)"
    fi

  else
    #Dumbest job request possible, request memory and a single CPU for a generic cluster
    qbatch_atlas_template_opts="-c 1 -j 1 --mem ${atlas_template_memory}G --walltime $(echo ${atlas_template_walltime_seconds} * 8 | bc)"
    qbatch_template_subject_opts="-c 1 -j 1 --mem ${template_subject_memory}G  --walltime $(echo ${template_subject_walltime_seconds} * 8 | bc)"
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
    done | ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=8 qbatch ${dryrun} --jobname ${datetime}-mb_register_atlas_template-${templatename} ${qbatch_atlas_template_opts} -
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
  done | ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=2 qbatch ${dryrun} -j 4 -c 1000 --depend "${datetime}-mb_register_atlas_template*" --jobname ${datetime}-mb-multiatlas_resample --walltime 4:00:00 -
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
  done | ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=4 qbatch ${dryrun} -j 2 -c 100 --depend "${datetime}-mb-multiatlas_resample*" --jobname ${datetime}-mb-multiatlas_vote --walltime 4:00:00 -
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
    done | ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=4 qbatch ${dryrun} --jobname ${datetime}-mb_register_template_subject-${subjectname} ${qbatch_template_subject_opts} -
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
    done | ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=2 qbatch ${dryrun} -j 4 -c 1000 --depend "${datetime}-mb_register_atlas_template*" --depend "${datetime}-mb_register_template_subject-${subjectname}*" --jobname ${datetime}-mb_resample-${subjectname} --walltime 12:00:00 -
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
    done | ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=4 qbatch ${dryrun} -j 2 -c 100 --depend "${datetime}-mb_resample-${subjectname}*" --jobname ${datetime}-mb_vote-${subjectname} --walltime 4:00:00 -
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
