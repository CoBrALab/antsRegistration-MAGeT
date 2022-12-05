#!/bin/bash

# ARG_HELP([<The general help message of my script>])
# ARG_OPTIONAL_SINGLE([input-dir],[],[Input directory for MAGeT-Brain],[input])
# ARG_OPTIONAL_SINGLE([output-dir],[],[Output directory for MAGeT-Brain],[output])
# ARG_OPTIONAL_SINGLE([primary-spectra],[],[The primary spectra used to determine fixed images for registration and resampling],[T1w])
# ARG_TYPE_GROUP_SET([spectragroup],[SPECTRA],[primary-spectra],[T1w,T2w,PDw,UNIT1])
# ARG_OPTIONAL_SINGLE([label-masking],[],[Use merged labels as masks for registration, 'partial' uses it only for moving images, 'full' affinely resamples masks into fixed spaces and merges before non-linear registration],[partial])
# ARG_TYPE_GROUP_SET([labelmaskingroup],[LABELMASKING],[label-masking],[none,partial,full])
# ARG_POSITIONAL_SINGLE([stage],[Stage to run],[run])
# ARG_OPTIONAL_BOOLEAN([fast],[],[Run fast SyN registration])
# ARG_OPTIONAL_BOOLEAN([dry-run],[],[Dry run, don't run any commands, implies debug],[])
# ARG_OPTIONAL_BOOLEAN([verbose],[v],[Run commands verbosely],[on])
# ARG_OPTIONAL_BOOLEAN([debug],[d],[Show all internal comands and logic for debug],[])
# ARGBASH_GO()
# needed because of Argbash --> m4_ignore([
### START OF CODE GENERATED BY Argbash v2.10.0 one line above ###
# Argbash is a bash code generator used to get arguments parsing right.
# Argbash is FREE SOFTWARE, see https://argbash.io for more info


die()
{
	local _ret="${2:-1}"
	test "${_PRINT_HELP:-no}" = yes && print_help >&2
	echo "$1" >&2
	exit "${_ret}"
}

# validators

spectragroup()
{
	local _allowed=("T1w" "T2w" "PDw" "UNIT1") _seeking="$1"
	for element in "${_allowed[@]}"
	do
		test "$element" = "$_seeking" && echo "$element" && return 0
	done
	die "Value '$_seeking' (of argument '$2') doesn't match the list of allowed values: 'T1w', 'T2w', 'PDw' and 'UNIT1'" 4
}


labelmaskingroup()
{
	local _allowed=("none" "partial" "full") _seeking="$1"
	for element in "${_allowed[@]}"
	do
		test "$element" = "$_seeking" && echo "$element" && return 0
	done
	die "Value '$_seeking' (of argument '$2') doesn't match the list of allowed values: 'none', 'partial' and 'full'" 4
}


begins_with_short_option()
{
	local first_option all_short_options='hvd'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=()
_arg_stage="run"
# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_input_dir="input"
_arg_output_dir="output"
_arg_primary_spectra="T1w"
_arg_label_masking="partial"
_arg_fast="off"
_arg_dry_run="off"
_arg_verbose="on"
_arg_debug="off"


print_help()
{
	printf '%s\n' "<The general help message of my script>"
	printf 'Usage: %s [-h|--help] [--input-dir <arg>] [--output-dir <arg>] [--primary-spectra <SPECTRA>] [--label-masking <LABELMASKING>] [--(no-)fast] [--(no-)dry-run] [-v|--(no-)verbose] [-d|--(no-)debug] [<stage>]\n' "$0"
	printf '\t%s\n' "<stage>: Stage to run (default: 'run')"
	printf '\t%s\n' "-h, --help: Prints help"
	printf '\t%s\n' "--input-dir: Input directory for MAGeT-Brain (default: 'input')"
	printf '\t%s\n' "--output-dir: Output directory for MAGeT-Brain (default: 'output')"
	printf '\t%s\n' "--primary-spectra: The primary spectra used to determine fixed images for registration and resampling. Can be one of: 'T1w', 'T2w', 'PDw' and 'UNIT1' (default: 'T1w')"
	printf '\t%s\n' "--label-masking: Use merged labels as masks for registration, 'partial' uses it only for moving images, 'full' affinely resamples masks into fixed spaces and merges before non-linear registration. Can be one of: 'none', 'partial' and 'full' (default: 'partial')"
	printf '\t%s\n' "--fast, --no-fast: Run fast SyN registration (off by default)"
	printf '\t%s\n' "--dry-run, --no-dry-run: Dry run, don't run any commands, implies debug (off by default)"
	printf '\t%s\n' "-v, --verbose, --no-verbose: Run commands verbosely (on by default)"
	printf '\t%s\n' "-d, --debug, --no-debug: Show all internal comands and logic for debug (off by default)"
}


parse_commandline()
{
	_positionals_count=0
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-h|--help)
				print_help
				exit 0
				;;
			-h*)
				print_help
				exit 0
				;;
			--input-dir)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_input_dir="$2"
				shift
				;;
			--input-dir=*)
				_arg_input_dir="${_key##--input-dir=}"
				;;
			--output-dir)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_output_dir="$2"
				shift
				;;
			--output-dir=*)
				_arg_output_dir="${_key##--output-dir=}"
				;;
			--primary-spectra)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_primary_spectra="$(spectragroup "$2" "primary-spectra")" || exit 1
				shift
				;;
			--primary-spectra=*)
				_arg_primary_spectra="$(spectragroup "${_key##--primary-spectra=}" "primary-spectra")" || exit 1
				;;
			--label-masking)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_label_masking="$(labelmaskingroup "$2" "label-masking")" || exit 1
				shift
				;;
			--label-masking=*)
				_arg_label_masking="$(labelmaskingroup "${_key##--label-masking=}" "label-masking")" || exit 1
				;;
			--no-fast|--fast)
				_arg_fast="on"
				test "${1:0:5}" = "--no-" && _arg_fast="off"
				;;
			--no-dry-run|--dry-run)
				_arg_dry_run="on"
				test "${1:0:5}" = "--no-" && _arg_dry_run="off"
				;;
			-v|--no-verbose|--verbose)
				_arg_verbose="on"
				test "${1:0:5}" = "--no-" && _arg_verbose="off"
				;;
			-v*)
				_arg_verbose="on"
				_next="${_key##-v}"
				if test -n "$_next" -a "$_next" != "$_key"
				then
					{ begins_with_short_option "$_next" && shift && set -- "-v" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
				fi
				;;
			-d|--no-debug|--debug)
				_arg_debug="on"
				test "${1:0:5}" = "--no-" && _arg_debug="off"
				;;
			-d*)
				_arg_debug="on"
				_next="${_key##-d}"
				if test -n "$_next" -a "$_next" != "$_key"
				then
					{ begins_with_short_option "$_next" && shift && set -- "-d" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
				fi
				;;
			*)
				_last_positional="$1"
				_positionals+=("$_last_positional")
				_positionals_count=$((_positionals_count + 1))
				;;
		esac
		shift
	done
}


handle_passed_args_count()
{
	test "${_positionals_count}" -le 1 || _PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect between 0 and 1, but got ${_positionals_count} (the last one was: '${_last_positional}')." 1
}


assign_positional_args()
{
	local _positional_name _shift_for=$1
	_positional_names="_arg_stage "

	shift "$_shift_for"
	for _positional_name in ${_positional_names}
	do
		test $# -gt 0 || break
		eval "$_positional_name=\${1}" || die "Error during argument parsing, possibly an Argbash bug." 1
		shift
	done
}

parse_commandline "$@"
handle_passed_args_count
assign_positional_args 1 "${_positionals[@]}"

# OTHER STUFF GENERATED BY Argbash
# Validation of values



### END OF CODE GENERATED BY Argbash (sortof) ### ])
# [ <-- needed because of Argbash

set -uo pipefail
set -eE -o functrace

### BASH HELPER FUNCTIONS ###
# Stolen from https://github.com/kvz/bash3boilerplate

# Set magic variables for current file, directory, os, etc.
__dir="$(cd "$(dirname "${BASH_SOURCE[${__b3bp_tmp_source_idx:-0}]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[${__b3bp_tmp_source_idx:-0}]}")"
__base="$(basename "${__file}" .sh)"
# shellcheck disable=SC2034,SC2015
__invocation="$(printf %q "${__file}")$( (($#)) && printf ' %q' "$@" || true)"
# Calculator for maths
calc () { awk "BEGIN{ print $* }" ;}

# Setup a timestamp for prefixing all commands
__datetime=$(date -u +%F_%H-%M-%S-UTC)

### BASH HELPER FUNCTIONS ###
# Stolen from https://github.com/kvz/bash3boilerplate"

if [[ ${_arg_dry_run} == "on" || ${_arg_debug} == "on" ]]; then
  LOG_LEVEL=7
else
  LOG_LEVEL=6
fi

function __b3bp_log() {
  local log_level="${1}"
  shift

  # shellcheck disable=SC2034
  local color_debug="\\x1b[35m" #]
  # shellcheck disable=SC2034
  local color_info="\\x1b[32m" #]
  # shellcheck disable=SC2034
  local color_notice="\\x1b[34m" #]
  # shellcheck disable=SC2034
  local color_warning="\\x1b[33m" #]
  # shellcheck disable=SC2034
  local color_error="\\x1b[31m" #]
  # shellcheck disable=SC2034
  local color_critical="\\x1b[1;31m" #]
  # shellcheck disable=SC2034
  local color_alert="\\x1b[1;37;41m" #]
  # shellcheck disable=SC2034
  local color_failure="\\x1b[1;4;5;37;41m" #]

  local colorvar="color_${log_level}"

  local color="${!colorvar:-${color_error}}"
  local color_reset="\\x1b[0m" #]

  if [[ "${NO_COLOR:-}" = "true" ]] || { [[ "${TERM:-}" != "xterm"* ]] && [[ "${TERM:-}" != "screen"* ]]; } || [[ ! -t 2 ]]; then
    if [[ "${NO_COLOR:-}" != "false" ]]; then
      # Don't use colors on pipes or non-recognized terminals
      color=""
      color_reset=""
    fi
  fi

  # all remaining arguments are to be printed
  local log_line=""

  while IFS=$'\n' read -r log_line; do
    echo -e "$(date -u +"%Y-%m-%d %H:%M:%S UTC") ${color}$(printf "[%9s]" "${log_level}")${color_reset} $(echo ${log_line} | tr -s "[:blank:]")" 1>&2
  done <<<"${@:-}"
}

function failure() {
  __b3bp_log failure "${@}"
  exit 1
}
function alert() {
  [[ "${LOG_LEVEL:-0}" -ge 1 ]] && __b3bp_log alert "${@}"
  true
}
function critical() {
  [[ "${LOG_LEVEL:-0}" -ge 2 ]] && __b3bp_log critical "${@}"
  true
}
function error() {
  [[ "${LOG_LEVEL:-0}" -ge 3 ]] && __b3bp_log error "${@}"
  true
}
function warning() {
  [[ "${LOG_LEVEL:-0}" -ge 4 ]] && __b3bp_log warning "${@}"
  true
}
function notice() {
  [[ "${LOG_LEVEL:-0}" -ge 5 ]] && __b3bp_log notice "${@}"
  true
}
function info() {
  [[ "${LOG_LEVEL:-0}" -ge 6 ]] && __b3bp_log info "${@}"
  true
}
function debug() {
  [[ "${LOG_LEVEL:-0}" -ge 7 ]] && __b3bp_log debug "${@}"
  true
}

# Add handler for failure to show where things went wrong
failure_handler() {
  local lineno=$2
  local fn=$3
  local exitstatus=$4
  local msg_orig=$5
  local msg_expanded=$(eval echo \"$5\")
  local lineno_fns=${1% 0}
  if [[ "$lineno_fns" != "0" ]] ; then
    lineno="${lineno} ${lineno_fns}"
  fi
  failure "${BASH_SOURCE[1]}:${fn}[${lineno}] Failed with status ${exitstatus}: \n\t${msg_orig}\n\t${msg_expanded}"
}
trap 'failure_handler "${BASH_LINENO[*]}" "$LINENO" "${FUNCNAME[*]:-script}" "$?" "$BASH_COMMAND"' ERR

# This function is used to cleanly exit any script. It does this displaying a
# given error message, and exiting with an error code.
function error_exit {
    failure "$@"
}
# Trap the killer signals so that we can exit with a good message.
trap "error_exit 'Exiting: Received signal SIGHUP'" SIGHUP
trap "error_exit 'Exiting: Received signal SIGINT'" SIGINT
trap "error_exit 'Exiting: Received signal SIGTERM'" SIGTERM

function run_smart {
  # Function runs the command it wraps if the file does not exist
  if [[ ! -s "$1" ]]; then
    "$2"
  fi
}

function extension_strip()
{
  sed -r 's/(.nii$|.nii.gz|.nrrd|.mnc|.mnc.gz)$//'
}

function spectra_strip()
{
  sed -r 's/(_T1w|_T2w|_PDw|_UNIT1)$//'
}

###################################################

if [[ ${_arg_stage} == "init" ]]; then
	mkdir -p input/{atlases,templates,subjects}/{brains,masks}
	mkdir -p input/atlases/labels
	exit
fi

if [[ ${_arg_fast} == "on" ]]; then
	_arg_fast="--fast"
else
	_arg_fast=""
fi

mkdir -p ${_arg_output_dir}/{logs,jobs}/${__datetime}
mkdir -p ${_arg_output_dir}/intermediate/{atlas-template,template-subject,labels}
mkdir -p ${_arg_output_dir}/labels/majorityvote


shopt -s nullglob
# Collect all input files
atlases=( ${_arg_input_dir}/atlases/brains/*_${_arg_primary_spectra}{*mnc,*nrrd,*nii.gz,*nii} )
templates=( ${_arg_input_dir}/templates/brains/*_${_arg_primary_spectra}{*mnc,*nrrd,*nii.gz,*nii} )
subjects=( ${_arg_input_dir}/subjects/brains/*_${_arg_primary_spectra}{*mnc,*nrrd,*nii.gz,*nii} )

# Generate atlas masks for label masking (if used)
if [[  ${_arg_label_masking} == "partial"  ||  ${_arg_label_masking} == "full"  ]]; then
  continue
fi

info "Computing atlas to template linear transforms"
# Perform linear atlas to template registration
for template in "${templates[@]}"; do
	templatename=$(basename ${template} | extension_strip | spectra_strip)
	mkdir -p ${_arg_output_dir}/intermediate/transforms/atlas-template/${templatename}
	for atlas in "${atlases[@]}"; do
		atlasname=$(basename ${atlas} | extension_strip | spectra_strip)
		if [[ ! ( -s ${_arg_output_dir}/intermediate/transforms/atlas-template/${templatename}/${atlasname}-${templatename}_0_GenericAffine.xfm || -s ${_arg_output_dir}/intermediate/transforms/atlas-template/${templatename}/${atlasname}-${templatename}_0GenericAffine.mat ) ]]; then
			echo antsRegistration_affine_SyN.sh \
				${_arg_fast} \
				--skip-nonlinear \
				--histogram-matching \
				${atlas} ${template} \
				${_arg_output_dir}/intermediate/transforms/atlas-template/${templatename}/${atlasname}-${templatename}_
		fi
	done
done

info "Computing atlas to template non-linear transforms"
# Perform non-linear atlas to template registration
for template in "${templates[@]}"; do
	templatename=$(basename ${template} | extension_strip | spectra_strip)
	mkdir -p ${_arg_output_dir}/intermediate/transforms/atlas-template/${templatename}
	for atlas in "${atlases[@]}"; do
		atlasname=$(basename ${atlas} | extension_strip | spectra_strip)
		if [[ ! ( -s ${_arg_output_dir}/intermediate/transforms/atlas-template/${templatename}/${atlasname}-${templatename}_1_NL.xfm || -s ${_arg_output_dir}/intermediate/transforms/atlas-template/${templatename}/${atlasname}-${templatename}_1Warp.nii.gz ) ]]; then
			echo antsRegistration_affine_SyN.sh --clobber \
				${_arg_fast} \
				--skip-linear \
				--histogram-matching \
				--initial-transform ${_arg_output_dir}/intermediate/transforms/atlas-template/${templatename}/${atlasname}-${templatename}_0_GenericAffine.xfm \
				${atlas} ${template} \
				${_arg_output_dir}/intermediate/transforms/atlas-template/${templatename}/${atlasname}-${templatename}_
		fi
	done
done

info "Computing template to subject linear transforms"
# Perform linear template to subject registration
for subject in "${subjects[@]}"; do
	subjectname=$(basename ${subject} | extension_strip | spectra_strip)
	for template in "${templates[@]}"; do
		templatename=$(basename ${template} | extension_strip | spectra_strip)
		mkdir -p ${_arg_output_dir}/intermediate/transforms/template-subject/${subjectname}
		if [[ ${templatename} == ${subjectname} ]]; then
			continue
		else
			if [[ ! ( -s ${_arg_output_dir}/intermediate/transforms/template-subject/${subjectname}/${templatename}-${subjectname}_0_GenericAffine.xfm || -s ${_arg_output_dir}/intermediate/transforms/template-subject/${subjectname}/${templatename}-${subjectname}_0GenericAffine.mat ) ]]; then
				echo antsRegistration_affine_SyN.sh \
					${_arg_fast} \
					--skip-nonlinear \
					${template} ${subject} \
					${_arg_output_dir}/intermediate/transforms/template-subject/${subjectname}/${templatename}-${subjectname}_
			fi
		fi
	done
done

info "Computing template to subject non-linear transforms"
# Perform non-linear template to subject registration
for subject in "${subjects[@]}"; do
	subjectname=$(basename ${subject} | extension_strip | spectra_strip)
	for template in "${templates[@]}"; do
		templatename=$(basename ${template} | extension_strip | spectra_strip)
		mkdir -p ${_arg_output_dir}/intermediate/transforms/template-subject/${subjectname}
		if [[ ${templatename} == ${subjectname} ]]; then
			continue
		else
			if [[ ! ( -s ${_arg_output_dir}/intermediate/transforms/template-subject/${subjectname}/${templatename}-${subjectname}_1_NL.xfm || -s ${_arg_output_dir}/intermediate/transforms/template-subject/${subjectname}/${templatename}-${subjectname}_1Warp.nii.gz ) ]]; then
				echo antsRegistration_affine_SyN.sh --clobber \
					${_arg_fast} \
					--skip-linear \
					--histogram-matching \
					--initial-transform ${_arg_output_dir}/intermediate/transforms/template-subject/${subjectname}/${templatename}-${subjectname}_0_GenericAffine.xfm \
					${template} ${subject} \
					${_arg_output_dir}/intermediate/transforms/template-subject/${subjectname}/${templatename}-${subjectname}_
			fi
		fi
	done
done

info "Resample labels to subject space"
# Resample labels into subject space
for subject in "${subjects[@]}"; do
	subjectname=$(basename ${subject} | extension_strip | spectra_strip)
	mkdir -p ${_arg_output_dir}/intermediate/labels/${subjectname}
	for template in "${templates[@]}"; do
		templatename=$(basename ${template} | extension_strip | spectra_strip)
		for atlas in "${atlases[@]}"; do
			atlasname=$(basename ${atlas} | extension_strip | spectra_strip)
			labels=( ${_arg_input_dir}/atlases/labels/${atlasname}_label*{*mnc,*nrrd,*nii.gz,*nii} )
			for label in "${labels[@]}"; do
				labelname=$(basename ${label}  | grep -E -o '_label.*$')
				if [[ ! -s ${_arg_output_dir}/intermediate/labels/${subjectname}/${atlasname}-${templatename}-${subjectname}${labelname} ]]; then
					if [[ ${templatename} == ${subjectname} ]]; then
						echo antsApplyTransforms -d 3 --verbose -n GenericLabel \
							-i ${label} -r ${subject} \
							-t ${_arg_output_dir}/intermediate/transforms/atlas-template/${templatename}/${atlasname}-${templatename}_1_NL.xfm \
							-t ${_arg_output_dir}/intermediate/transforms/atlas-template/${templatename}/${atlasname}-${templatename}_0_GenericAffine.xfm \
							-o ${_arg_output_dir}/intermediate/labels/${subjectname}/${atlasname}-${templatename}-${subjectname}${labelname}
					else
						echo antsApplyTransforms -d 3 --verbose -n GenericLabel \
							-i ${label} -r ${subject} \
							-t ${_arg_output_dir}/intermediate/transforms/template-subject/${subjectname}/${templatename}-${subjectname}_1_NL.xfm \
							-t ${_arg_output_dir}/intermediate/transforms/template-subject/${subjectname}/${templatename}-${subjectname}_0_GenericAffine.xfm \
							-t ${_arg_output_dir}/intermediate/transforms/atlas-template/${templatename}/${atlasname}-${templatename}_1_NL.xfm \
							-t ${_arg_output_dir}/intermediate/transforms/atlas-template/${templatename}/${atlasname}-${templatename}_0_GenericAffine.xfm \
							-o ${_arg_output_dir}/intermediate/labels/${subjectname}/${atlasname}-${templatename}-${subjectname}${labelname}
					fi
				fi
			done
		done
	done
done

info "Performing Majority Vote label merging"
# Figure out the names of all the labels to loop over
atlasname=$(basename ${atlases[0]} | extension_strip | spectra_strip)
labels=( ${_arg_input_dir}/atlases/labels/${atlasname}_label*{*mnc,*nrrd,*nii.gz,*nii} )
for subject in "${subjects[@]}"; do
	subjectname=$(basename ${subject} | extension_strip | spectra_strip)
	for label in "${labels[@]}"; do
		labelname=$(basename ${label} | grep -E -o '_label.*$')
		if [[ ! -s ${_arg_output_dir}/labels/majorityvote/${subjectname}${labelname} ]]; then
			label_array=()
			for atlas in "${atlases[@]}"; do
				atlasname=$(basename ${atlas} | extension_strip | spectra_strip)
				for template in "${templates[@]}"; do
					templatename=$(basename ${template} | extension_strip | spectra_strip)
					label_array+=( ${_arg_output_dir}/intermediate/labels/${subjectname}/${atlasname}-${templatename}-${subjectname}${labelname} )
				done
			done
			echo ImageMath 3 ${_arg_output_dir}/labels/majorityvote/${subjectname}${labelname} MajorityVoting "${label_array[@]}"
		fi
	done
done

# ] <-- needed because of Argbash
