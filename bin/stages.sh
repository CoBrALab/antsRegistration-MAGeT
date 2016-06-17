#Functions for various stages of mb.sh

stage_init () {
  info "Creating input/atlas input/template input/subject"
  mkdir -p input/atlas input/template input/subject input/model
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
    done | ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=5 qbatch ${dryrun} -j 2 -c 4 ${hires} --jobname ${datetime}-mb_register_atlas_template-${templatename} --walltime 5:00:00 -
  done
}

stage_multiatlas () {
  debug "Setting up Multiatlas/Template Output Directories"
  mkdir -p output/multiatlas/labels/candidates
  mkdir -p output/multiatlas/labels/majorityvote
  for template in ${templates}
  do
    mkdir -p output/multiatlas/labels/candidates/$(basename ${template})
  done
  #Resample candidate labels
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

  #Voting
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
    done | ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=4 qbatch ${dryrun} -j 2 -c 8 --jobname ${datetime}-mb_register_template_subject-${subjectname} --walltime 10:00:00 -
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
}
