#!/usr/bin/env bash
export LANG=C
export LANGUAGE=C
export LC_CTYPE=C
export LC_NUMERIC=C
export LC_TIME=C
export LC_COLLATE=C
export LC_MONETARY=C
export LC_MESSAGES=C
export LC_PAPER=C
export LC_NAME=C
export LC_ADDRESS=C
export LC_TELEPHONE=C
export LC_MEASUREMENT=C
export LC_IDENTIFICATION=C
export LC_ALL=C

#Setup some extra environment settings
export QBATCH_SCRIPT_FOLDER="output/.qbatch/"

read -r -d '' __usage <<-'EOF' || true # exits non-zero when EOF encountered
  -s --subject         [arg]  Specific subject files to process.
  -t --template        [arg]  Specific template files to process.
  -v --verbose                Enable verbose mode for all scripts.
  -d --debug                  Enables debug mode.
  -h --help                   This help page.
  -n --dry-run                Don't submit any jobs. Useful with debug above.
  -r --reg-command     [arg]  Provide an alternative registration command.  Default="mb_register.sh"
  -m --mem-factor      [arg]  Scaling factor for memory estimates.          Default="1.10"
  -w --walltime-factor [arg]  Scaling factor for time estimates.            Default="1.10"
  -l --label-masking          Use atlas labels to focus registration.
EOF

read -r -d '' __helptext <<-'EOF' || true # exits non-zero when EOF encountered
  MAGeTBrain implementation using ANTs
  Supports MINC and NIFTI input files (ANTs must be built with MINC support)

  Invocation: mb.sh [options] -- [stage 1] [stage 2] ... [stage N]

  Standard stages: template, subject, resample, vote, run (template, subject, resample, vote, qc)
  Multiatlas stages: multiatlas-resample, multiatlas-vote, multiatlas (template, multiatlas-resample, multiatlas-vote)
  Other stages: init, status, cleanup
  Multiple commands will run multiple stages. Order is not checked.
EOF

# shellcheck source=header.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/header.sh"
# shellcheck source=stages.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stages.sh"

### Command-line argument switches (like -d for debugmode, -h for showing helppage)
##############################################################################

# debug mode
if [ "${arg_d:?}" = "1" ]; then
    set -o xtrace
    LOG_LEVEL="7"
fi

# verbose mode
if [ "${arg_v:?}" = "1" ]; then
    #set -o verbose
    export MB_VERBOSE='--verbose'
else
    export MB_VERBOSE=''
fi

# dry-run mode
if [ "${arg_n:?}" = "1" ]; then
    dryrun='-n'
else
    dryrun=''
fi

# label masking
if [ "${arg_l:?}" = "1" ]; then
    __mb_label_masking='1'
else
    __mb_label_masking=''
fi

# help mode
if [[ "${arg_h:?}" = "1" ]]; then
    # Help exists with code 1
    help "Help using ${0}"
fi

__memory_scaling_factor=${arg_m}
__walltime_scaling_factor=${arg_w}

### Runtime
##############################################################################

function cleanup_before_exit () {
    info "Cleaning up. Done"
}
trap cleanup_before_exit EXIT

#All jobs are prefixed with a date-time in ISO format(to the minute) so you can submit multiple jobs at once
__datetime=T$(date -u +%F_%H-%M-%S)

#If the commandlist is empty, assume the command is "run"
if [[ $# -lt 1 ]]
then
    commandlist="run"
else
    commandlist="$*"
fi

if [[ ${commandlist} =~ "init" ]]
then
    stage_init
    exit 0
elif [[ ! (-e input/atlas && -e input/template && -e input/subject )]]
then
    error "Error, input directories not found, run mb.sh -- init" && exit 1
fi

#Collect a list of atlas/template/subject files, must be named _t1.(nii,nii.gz,mnc, hdr/img)
atlases=$(find input/atlas -maxdepth 1 -name '*_t1.mnc' -o -name '*_t1.nii' -o -name '*_t1.nii.gz' -o -name '*_t1.hdr' -o -name '*_T1w.nii.gz')

if [[ ! -z "${arg_s:-}" ]]
then
    subjects=${arg_s}
    info "Specific subject(s) specified ${subjects}"
else
    subjects=$(find input/subject -maxdepth 1 -name '*_t1.mnc' -o -name '*_t1.nii' -o -name '*_t1.nii.gz' -o -name '*_t1.hdr' -o -name '*_T1w.nii.gz')
fi

if [[ ! -z "${arg_t:-}" ]]
then
    templates=${arg_t}
    info "Specific template(s) specified ${templates}"
else
    templates=$(find input/template -maxdepth 1 -name '*_t1.mnc' -o -name '*_t1.nii' -o -name '*_t1.nii.gz' -o -name '*_t1.hdr'  -o -name '*_T1w.nii.gz')
fi

models=$(find input/model -maxdepth 1 -name '*_t1.mnc' -o -name '*_t1.nii' -o -name '*_t1.nii.gz' -o -name '*_t1.hdr' -o -name '*_T1w.nii.gz' 2> /dev/null || true)

#Labels are figured out by looking at only the first atlas, and substituting t1 for label*
labels=$(ls $(echo ${atlases} | cut -d " " -f 1 | sed -r 's/_(t1|T1w|t2|T2w).*/_label\*/g') | sed 's/input.*label/label/g' || true)


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

if [[ $(( $(find input/atlas -maxdepth 1 -name '*label*' | wc -l) % $(echo ${atlases} | wc -w) )) -ne 0 ]]
then
    error "Unbalanced number of label files vs atlases, please ensure one label per type per atlas" && exit 1
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
debug "  output/jobscripts"
mkdir -p output/transforms/atlas-template
mkdir -p output/transforms/template-subject
mkdir -p output/labels/candidates
mkdir -p output/labels/majorityvote
mkdir -p output/jobscripts

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

#Exit if status exists in command list, doesn't matter if other commands were listed
[[ ${commandlist} =~ "status" ]] && exit 0

echo ${__invocation} > output/jobscripts/${__datetime}-mb_run_command

for stage in ${commandlist}
do
  case ${stage} in
    status)
      stage_status
      ;;&
    template|subject|multiatlas|run)
      stage_estimate
      ;;&
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
      ;;&
    qc|run)
      stage_qc
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
