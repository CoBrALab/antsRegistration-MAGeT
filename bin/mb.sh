#!/usr/bin/env bash
export LC_ALL=C
source header.sh
source stages.sh


#All jobs are prefixed with a date-time in ISO format(to the minute) so you can submit multiple jobs at once
datetime=$(date -u +%F-%R:%S)

#If the commandlist is empty, assume the command is "run"
if [[ $# < 1 ]]
then
    commandlist="run"
else
    commandlist="$@"
fi

if [[ $commandlist =~ "init" ]]
then
  stage_init
  exit 0
elif [[ ! (-e input/atlas && -e input/template && -e input/subject )]]
then
  error "Error, input directories not found, run mb.sh -- init" && exit 1
fi

#Collect a list of atlas/template/subject files, must be named _t1.(nii,nii.gz,mnc, hdr/img)
atlases=$(find input/atlas -maxdepth 1 -name '*_t1.mnc' -o -name '*_t1.nii' -o -name '*_t1.nii.gz' -o -name '*_t1.hdr')
templates=$(find input/template -maxdepth 1 -name '*_t1.mnc' -o -name '*_t1.nii' -o -name '*_t1.nii.gz' -o -name '*_t1.hdr')

if [[ ! -z "${arg_s:-}" ]]
then
  subjects=${arg_s}
  info "Single subject specified ${subjects}"
else
  subjects=$(find input/subject -maxdepth 1 -name '*_t1.mnc' -o -name '*_t1.nii' -o -name '*_t1.nii.gz' -o -name '*_t1.hdr')
fi

models=$(find input/model -maxdepth 1 -name '*_t1.mnc' -o -name '*_t1.nii' -o -name '*_t1.nii.gz' -o -name '*_t1.hdr' 2> /dev/null || true)


#Labels are figured out by looking at only the first atlas, and substituting t1 for label*
labels=$(ls $(echo ${atlases} | cut -d " " -f 1 | sed 's/t1/label\*/g') | sed 's/input.*label/label/g' || true)

#Sanity Check on inputs
if [[ $(echo ${atlases} | wc -w) == 0 ]]
then
  error "Zero atlases found, please check input/atlas/*_t1.[mnc, nii, nii.gz]" && exit 1
fi

if [[ $(echo ${templates} | wc -w) == 0 ]]
then
  error "Zero templates found, please check input/template/*_t1.[mnc, nii, nii.gz]" && exit 1
fi

if [[ $(echo ${subjects} | wc -w) == 0 ]]
then
  warning "Zero subjects found, please check input/subject/*_t1.[mnc, nii, nii.gz], this is okay if performing multiatlas"
fi

if [[ $(( $(echo ${atlases} | wc -w) % 2 )) == 0 ]]
then
  warning "Even number of atlases detected, use an odd number to avoid tie label votes"
fi

if [[ $(( $(echo ${templates} | wc -w) % 2 )) == 0 ]]
then
  warning "Even number of templates detected, use an odd number to avoid tie label votes"
fi

#Sanity check on Analyze files, check that a matching img file exists
if [[ ${atlases} =~ "hdr" ]]
then
  for atlas in ${atlases}
  do
    if [[ ! -s input/atlas/$(basename ${atlas} .hdr).img ]]
    then
      error "atlas ${atlas} is missing corresponding input/atlas/$(basename ${atlas} .hdr).img file"
    fi
  done
fi

if [[ ${templates} =~ "hdr" ]]
then
  for template in ${templates}
  do
    if [[ ! -s input/template/$(basename ${template} .hdr).img ]]
    then
      error "template ${template} is missing corresponding input/template/$(basename ${template} .hdr).img file"
    fi
  done
fi

if [[ ${subjects} =~ "hdr" ]]
then
  for subject in ${subjects}
  do
    if [[ ! -s input/subject/$(basename ${subject} .hdr).img ]]
    then
      error "subject ${subject} is missing corresponding input/subject/$(basename ${subject} .hdr).img file"
    fi
  done
fi

#Alternative registration commands can be specified
#Must accept $movingfile $fixedfile $outputprefix
regcommand=${arg_r}

#Create directories
debug "Creating output directories"
debug "  output/transforms/atlas-template"
debug "  output/transforms/template-subject"
debug "  output/labels/candidates"
debug "  output/labels/majorityvote"
mkdir -p output/transforms/atlas-template
mkdir -p output/transforms/template-subject
mkdir -p output/labels/candidates
mkdir -p output/labels/majorityvote

for subject in ${subjects}
do
  debug "Creating output/labels/candidates/$(basename ${subject}) output/transforms/template-subject/$(basename ${subject})"
  mkdir -p output/labels/candidates/$(basename ${subject})
  mkdir -p output/transforms/template-subject/$(basename ${subject})
done

for template in ${templates}
do
  debug "Creating output/transforms/atlas-template/$(basename ${template})"
  mkdir -p output/transforms/atlas-template/$(basename ${template})
done

#Status printout
info "Found:"
info "  $(echo ${atlases} | wc -w) atlases in input/atlas"
info "  $(echo ${labels} | wc -w) labels in input/atlas"
info "  $(echo ${templates} | wc -w) templates in input/template"
info "  $(echo ${subjects} | wc -w) subjects in input/subject"
info "  $(echo ${models} | wc -w) models in input/models"

info "Progress:"
info "  $(find output/transforms/atlas-template -name '*0_GenericAffine.xfm' | wc -l) of $(( $(echo ${atlases} | wc -w) * $(echo ${templates} | wc -w) )) atlas-template registrations completed"
info "  $(find output/transforms/template-subject -name '*0_GenericAffine.xfm' | wc -l) of $(( $(echo ${templates} | wc -w) * $(echo ${subjects} | wc -w) - $(echo ${templates} | wc -w) )) template-subject registrations completed"
info "  $(find output/labels/candidates -type f | wc -l) of $(( $(echo ${atlases} | wc -w) * $(echo ${templates} | wc -w) * $(echo ${subjects} | wc -w) * $(echo ${labels} | wc -w) )) resample labels completed"
info "  $(ls output/labels/majorityvote | wc -l) of $(( $(echo ${subjects} | wc -w) * $(echo ${labels} | wc -w) )) voted labels completed"
if [[ -d output/multiatlas ]]
then
  info "  $(find output/multiatlas/labels/candidates -type f | wc -l) of $(( $(echo ${atlases} | wc -w) * $(echo ${templates} | wc -w) * $(echo ${labels} | wc -w) )) multiatlas resample labels completed"
  info "  $(ls output/labels/majorityvote | wc -l) of $(( $(echo ${templates} | wc -w) * $(echo ${labels} | wc -w) )) multiatlas voted labels completed"
fi

#Exit if status exists in command list, doesn't matter if other commands were listed
[[ $commandlist =~ "status" ]] && exit 0

# info "Checking dimensions of first atlas"
# SIZE=( $(PrintHeader $(echo ${atlases} | cut -d " " -f 1) 1 | tr 'x' '\n') )
# for dim in ${SIZE[@]}
# do
#   if [[ $(echo "$dim < 1.0" | bc) == 1 ]]
#   then
#     notice "High resolution atlas detected, atlas-template registrations will be submitted to 32GB nodes on SciNet"
#     hires="--highmem"
#     break
#   else
#     hires=''
#   fi
# done

for stage in $commandlist
do
  case ${stage} in
    template|multiatlas|run)
      stage_register_atlas_template
      ;;&
    multiatlas|multiatlas-resample)
      stage_multiatlas_resample
      ;;&
    multiatlas|multiatlas-vote)
      stage_multiatlas_vote
      exit 0
      ;;
    subject|run)
      stage_register_template_subject
      ;;&
    resample|run)
      stage_resample
      ;;&
    vote|run)
      stage_vote
      exit 0
      ;;
    cleanup)
      stage_cleanup
      exit 0
      ;;
    template|multiatlas|multiatlas-resample|multiatlas-vote|subject|resample|vote|cleanup|run)
      #Catch the fall-through of case matching before erroring
      ;;
    *)
      error "Stage not recognized" && help
  esac
done
