#!/usr/bin/env bash
# Defining the makefile commands
# make <command>:<target>

# ANSI terminal colors (see 'man tput') ----- {{{1
# See 'man tput' and https://linuxtidbits.wordpress.com/2008/08/11/output-color-on-bash-scripts/. Don't use color if there isn't a $TERM environment variable.
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
WHITE=$(tput setaf 7)
RESET=$(tput sgr0)
readonly BOLD
readonly RED
readonly GREEN
readonly YELLOW
readonly BLUE
readonly MAGENTA
readonly WHITE
readonly RESET
#}}}1

# Default commands ------------------------------------------------------------------------- {{{1
readonly TRASH_COMMAND='/usr/bin/env gio trash'
readonly CP_COMMAND='/usr/bin/env cp'
readonly GIT_COMMAND='/usr/bin/env git'
readonly MKDIR_COMMAND='/usr/bin/env mkdir'
readonly SED_COMMAND='/usr/bin/env sed'
#}}}1

# Default values -------------------------------------------------------------------------- {{{1
readonly LIBDIR='libraries'
readonly KICADDIR='kicad_files'
readonly ACRNPRJ_REPO='git@github.com:AcheronProject'
readonly ALLOWED_SWITCHTYPES=(MX MX_soldermask MXA MXH)
readonly ALLOWED_TEMPLATES=(BLANK J48 J64)
readonly SED_BACKUP_EXT='.bak'

VERBOSE=0
NOGRAPHICS=0
NO3D=0
NOLOGOS=0
NO_GIT_REPO=0
NO_GIT_SUBMODULES=0
CLEANCREATE=0
PURGECLEAN=0
SWITCHTYPE='MX'
PRJNAME='project'
TEMPLATE='BLANK'
OUTPUT_REDIRECTION='&>/dev/null'
#}}}1

# Printing functions ----------------------------------------------------------------------------- {{{1
function echo_text() {
	local TEXT_TO_PRINT="${*:$#}"  # Assuming it's the last parameter
	local ECHO_ARGS="${*%"${!#}"}" # Assuming it's the rest
	echo ${ECHO_ARGS} "${TEXT_TO_PRINT}" >&1
}

function echo2stdout() {
	echo_text "$@" >&1
}

function echo2stderr() {
	echo_text "$@" >&2
}

function verbose_logging() {
	[[ "${VERBOSE}" -eq 1 ]] && echo2stdout "$@"
}
# }}}1

# Usage function -------------------------------------------------------------------------------- {{{1
# This function displays the usage section of the code/
function usage() {
	echo2stderr "${BOLD}ACHERON PROJECT KEYBOARD CREATOR TOOL ${RESET}
${BOLD}Created by:${RESET} Álvaro \"Gondolindrim\" Volpato
${BOLD}Link:${RESET} https://acheronproject.com/acheron_setup/acheron_setup/
${BOLD}Version:${RESET} 1.0 (november 4, 2021)
${BOLD}Description: ${RESET}The Acheron Keyboard Creator tool is a bash-script tool aimed at automating the process of creating a KiCAD PCB project for a keyboard PCB. The produced files are ready-to-use and can be edited and modified using the latest KiCAD nightly (november 4, 2021 or newer) and include configuration settings such as copper clearance and tolerance, soldermask clearance and minimum width aimed at being compatible across multiple factories.
${BOLD}Usage: $0 [options] [arguments] (Note: ${GREEN}green${WHITE} values signal default values. Options and arguments are case-sensitive.)
${GREEN}>>${WHITE} Options:${RESET}
	${BOLD}[-h,  --help]${RESET}		Displays this message and exists.
	${BOLD}[-v,  --verbose]${RESET}	Enable verbose logging.
	${BOLD}[-pc, --purgeclean]${RESET}	Deletes all generated files before execution (*.git folders and files and the KICADDIR), leaving only the original repository, and proceeds normal execution. ${BOLD}${GREEN}(F)${RESET}
	${BOLD}[-cc, --cleancreate]${RESET}	Creates cleanly, removing all base files including this script, leaving only the final files. ${BOLD}${GREEN}(F)${RESET}
	${BOLD}[-ng, --nographics]${RESET}	Do not include graphics library submodule. ${BOLD}${GREEN}(F)${RESET}
	${BOLD}[-nl, --nologos]${RESET}	Do not include logos library submodule. ${BOLD}${GREEN}(F)${RESET}
	${BOLD}[-n3, --no3d]${RESET}		Do not include 3D models library submodule. ${BOLD}${GREEN}(F)${RESET}
	${BOLD}[-nr, --norepo]${RESET}		Do not init a git repository. ${BOLD}${GREEN}(F)${RESET}
	${BOLD}[-ns, --nosubmodule]${RESET}	Do not add libraries as git submodules. (Note: if the --norepo flag is not passed, a git repository will still be initiated). ${BOLD}${GREEN}(F)${RESET}
${GREEN}>>${BOLD}${WHITE} Arguments:${RESET}
	${BOLD}[-t,  --template]${RESET}	Choose what template to use. ${BOLD}Options are:
						${WHITE}- ${GREEN}'BLANK'${WHITE} for a blank PCB with pre-configured settings
						- 'J48' for the 48-pin joker template
						- 'J64' for the 64-pin joker template${RESET}
	${BOLD}[-p,  --projectname]${RESET}	Do not include 3D models library submodule. ${BOLD}${GREEN}('project')${RESET}
	${BOLD}[-kd, --kicaddir]${RESET}	Chooses the project parent folder name ${BOLD}${GREEN}('kicad_files')${RESET}
	${BOLD}[-ld, --libdir]${RESET}		Chooses the folder inside KICADDIR where libraries and submodules are added. ${BOLD}${GREEN}('libraries')${RESET}
	${BOLD}[-s,  --switchtype]${RESET}	Select what switch type library submodule to be added. ${BOLD}Options are:
						${WHITE}- ${GREEN}'MX'${WHITE} for simple MX support (https://github.com/AcheronProject/acheron_MX.pretty)
						- 'MX_soldermask' for MX support with covered front switches (https://github.com/AcheronProject/acheron_MX_soldermask.pretty)
						- 'MXA' for MX and Alps suport (https://github.com/AcheronProject/acheron_MXA.pretty)
						- 'MXH' for MX hostwap (https://github.com/AcheronProject/acheron_MXH.pretty)
${RESET}"
}
# }}}1

# kicad_setup function ---------------------- {{{1
# kicad_setup is a function that checks if kicaddir exists; if not, creates it; then copies the files in joker_template to kicaddir and adds symbol and footprint library tables.
# This function takes one argument: "TEMPLATE_NAME", which can be "blank", "joker48" or "joker64" pertaining to each available template.
kicad_setup() {
	local TEMPLATE_NAME="$1"
	local TEMPLATE_DIR='blank_template'
	local TEMPLATE_FILENAME='blank'

	if [[ -z "${TEMPLATE_NAME}" ]]; then
		echo2stderr "${RED}${BOLD}>> ERROR${WHITE} on function kicad_setup():${RESET} no argument passed."
		return 0
	fi

	case "${TEMPLATE_NAME}" in
		BLANK)
			;;
		J48)
			TEMPLATE_DIR='joker48_template'
			TEMPLATE_FILENAME='joker48'
			;;
		J64)
			TEMPLATE_DIR='joker64_template'
			TEMPLATE_FILENAME='joker64'
			;;
		*)
			echo2stderr "${RED}${BOLD}>> ERROR${WHITE} on function kicad_setup():${RESET} TEMPLATE_NAME option '${TEMPLATE_NAME}' unrecognized."
			return 0
	esac

	if [[ ! -d "${KICADDIR}" ]]; then
		echo2stdout -e "${BOLD}${RED}>> KiCAD directory at ${KICADDIR} not found, Libraries directory at ${KICADDIR}/${LIBDIR} not found.${WHITE} Creating them...${RESET} \c"
		eval "${MKDIR_COMMAND}" -p "${KICADDIR}/${LIBDIR}" "${OUTPUT_REDIRECTION}"
		echo2stdout " ${BOLD}${GREEN}Done.${RESET}"
	elif [[ ! -d "${KICADDIR}/${LIBDIR}" ]]; then
		echo2stdout -e "${BOLD}${GREEN}>> KiCAD directory found at ${KICADDIR}.${RESET}" ;
		echo2stdout -e "${BOLD}${RED}>> Libraries directory at ${KICADDIR}/${LIBDIR} not found.${WHITE} Creating it...${RESET} \c"
		eval "${MKDIR_COMMAND}" "${KICADDIR}/${LIBDIR}" "${OUTPUT_REDIRECTION}"
		echo2stdout "${BOLD}${GREEN}Done.${RESET}"
	fi

	eval "${CP_COMMAND}" "${TEMPLATE_DIR}/${TEMPLATE_FILENAME}.kicad_pro" "${KICADDIR}/${PRJNAME}.kicad_pro" "${OUTPUT_REDIRECTION}"
	eval "${CP_COMMAND}" "${TEMPLATE_DIR}/${TEMPLATE_FILENAME}.kicad_pcb" "${KICADDIR}/${PRJNAME}.kicad_pcb" "${OUTPUT_REDIRECTION}"
	eval "${CP_COMMAND}" "${TEMPLATE_DIR}/${TEMPLATE_FILENAME}.kicad_prl" "${KICADDIR}/${PRJNAME}.kicad_prl" "${OUTPUT_REDIRECTION}"
	eval "${CP_COMMAND}" "${TEMPLATE_DIR}/${TEMPLATE_FILENAME}.kicad_sch" "${KICADDIR}/${PRJNAME}.kicad_sch" "${OUTPUT_REDIRECTION}"
	eval "${CP_COMMAND}" "${TEMPLATE_DIR}/sym-lib-table" "${KICADDIR}/sym-lib-table" "${OUTPUT_REDIRECTION}"
	eval "${CP_COMMAND}" "${TEMPLATE_DIR}/fp-lib-table" "${KICADDIR}/fp-lib-table" "${OUTPUT_REDIRECTION}"

	return 1
}
#}}}1

# git "add" functions ----------------------- {{{1
# The git_add_library function does exactly that: adds a library to the project. However, this can be done in two ways: either as a git submodule or simply cloning the library from its repository; the behavior depends on the NO_GIT_SUBMODULES flag set when the script is called. The other two functions, add_symlib and add_footprint lib, are based on add_submodule. What they do, adittionally to adding a symbol or footprint library submodule, is also adding that library to KiCAD's library tables "sym-lib-table" and "fp-lib-table" throught the sed command. It must be noted that these two files should not be created from scratch as they have a header and a footer; hence, the template folders contain unedited, blank version of these files.
git_add_library() {
	local TARGET_LIBRARY="$1"
	local NO_GIT_SUBMODULES="$2"
	local TARGET_LIBRARY_GIT_REPO_URL="${ACRNPRJ_REPO}/${TARGET_LIBRARY}.git"
	local exit_code=

	if [[ -z "${TARGET_LIBRARY}" ]]; then
		echo2stderr "${RED}${BOLD}>> ERROR${WHITE} on function git_add_library():${RESET} no argument passed."
		return 0
	fi
	if [[ -z "${NO_GIT_SUBMODULES}" ]]; then
		echo2stderr "${RED}${BOLD}>> ERROR${WHITE} on function git_add_library():${RESET} not enough arguments passed (2 required, only 1 passed)."
		return 0
	fi

	if [[ "${NO_GIT_SUBMODULES}" -eq 0 ]]; then
		echo2stdout -e "${BOLD}>> Adding ${MAGENTA}${TARGET_LIBRARY}${WHITE} library as a submodule from ${BLUE}${BOLD}${TARGET_LIBRARY_GIT_REPO_URL}${RESET} at ${RED}${BOLD}\"${KICADDIR}/${LIBDIR}/${TARGET_LIBRARY}\"${RESET} folder... \c"
		eval "${GIT_COMMAND}" submodule add "${TARGET_LIBRARY_GIT_REPO_URL}" "${KICADDIR}/${LIBDIR}/${TARGET_LIBRARY}" "${OUTPUT_REDIRECTION}"
		exit_code=$?
	else
		echo2stdout -e "${BOLD}>> Cloning ${MAGENTA}${TARGET_LIBRARY}${WHITE} library from ${BLUE}${BOLD}${TARGET_LIBRARY_GIT_REPO_URL}${RESET} at ${RED}${BOLD}\"${KICADDIR}/${LIBDIR}/${TARGET_LIBRARY}\"${RESET} folder... \c"
		eval "${GIT_COMMAND}" clone "${TARGET_LIBRARY_GIT_REPO_URL}" "${KICADDIR}/${LIBDIR}/${TARGET_LIBRARY}" "${OUTPUT_REDIRECTION}"
		exit_code=$?
	fi

	if [[ ${exit_code} -ne 0 ]]; then
		echo2stderr "${RED}${BOLD}>> ERROR${WHITE} on function git_add_library():${RESET} an error occured when trying to clone ${TARGET_LIBRARY_GIT_REPO_URL}."
		return 0
	fi

	echo2stdout "${BOLD}${GREEN}Done.${RESET}"
	return 1
}

add_line_in_file() {
	local LINE="$1"
	local TARGET_FILE="$2"
	local LINE_NUMBER=${3:-2} # Default line number is 2
	local SED_ARGS="-i${SED_BACKUP_EXT} -e"
	local exit_code=

	eval "${SED_COMMAND}" "${SED_ARGS}" "'${LINE_NUMBER}i\\
${LINE}
'" "${TARGET_FILE}" "${OUTPUT_REDIRECTION}"
	exit_code=$?  # exit_code = 0 if the sed command was successfully executed

	if [[ ${exit_code} -eq 0 ]]; then
		eval "${TRASH_COMMAND}" "${TARGET_FILE}${SED_BACKUP_EXT}" "${OUTPUT_REDIRECTION}"
		return 1
	fi

	return 0
}

add_library() {
	local LIBRARY="$1"
	local NO_GIT_SUBMODULES="$2"
	local IS_FOOTPRINT=${3:-0} # Default is 0 => symbols library
	local PATH_TO_LIBRARY=
	local LIBRARY_TYPE=
	local LIBRARY_TABLE_FILE_PATH=
	local return_code=

	if [[ ${IS_FOOTPRINT} -eq 0 ]]; then
		PATH_TO_LIBRARY="${LIBDIR}/${LIBRARY}/${LIBRARY}.kicad_sym"
		LIBRARY_TYPE="symbol"
		LIBRARY_TABLE_FILE_PATH="${KICADDIR}/sym-lib-table"
	else
		LIBRARY="${LIBRARY}.pretty"
		PATH_TO_LIBRARY="${LIBDIR}/${LIBRARY}"
		LIBRARY_TYPE="footprint"
		LIBRARY_TABLE_FILE_PATH="${KICADDIR}/fp-lib-table"
	fi

	local LINE="(lib (name \"${LIBRARY}\")(type \"KiCad\")(uri \"\${KIPRJMOD}/${PATH_TO_LIBRARY}\")(options \"\")(descr \"Acheron Project ${LIBRARY_TYPE} library\"))"

	git_add_library "${LIBRARY}" "${NO_GIT_SUBMODULES}"
	return_code=$?

	if [[ ${return_code} -eq 1 ]]; then
		echo2stdout -e "${BOLD}>> Adding ${MAGENTA}${LIBRARY}${WHITE} ${LIBRARY_TYPE} library to KiCAD library table... \c"
		add_line_in_file "${LINE}" "${LIBRARY_TABLE_FILE_PATH}"
		return_code=$?

		if [[ ${return_code} -eq 1 ]]; then
			echo2stdout "${BOLD}${GREEN}Done.${RESET}"
		fi
	fi

	return ${return_code}
}
#}}}1

# clean() function: get the tool back to original state --------- {{{1
# This function deletes all *.git files and folders, also the ${KICADDIR}.
clean(){
	echo2stdout -e "${YELLOW}${BOLD}>> CLEANING${WHITE} produced files... \c"
	eval "${TRASH_COMMAND}" ./.git ./.gitmodules ./"${KICADDIR}" "${OUTPUT_REDIRECTION}"
	echo2stdout -e "${BOLD}${GREEN}Done.${RESET}"
}
#}}}1

# MAIN FUNCTION ----------------------------- {{{1
main(){
	if [[ $# -eq 0 ]]; then
		echo2stderr "${RED}${BOLD}>> ERROR${WHITE} on function main():${RESET} no argument passed."
		exit 7
	fi

	local TARGET_TEMPLATE="$1"
	local NOGRAPHICS="$2"
	local NOLOGOS="$3"
	local NO3D="$4"
	local LOCAL_CLEANCREATE="$5"
	local NO_GIT_REPO="$6"
	local NO_GIT_SUBMODULE="$7"
	local PURGECLEAN="$8"
	local SWITCHTYPE="$9"

	if [[ "${PURGECLEAN}" -eq 1 ]]; then clean; fi
	if [[ "${NO_GIT_REPO}" -eq 0 ]]; then
		echo2stdout -e "${BOLD}${GREEN}>>${WHITE} Initializing git repo... \c"
		eval "${GIT_COMMAND}" init "${OUTPUT_REDIRECTION}"
		eval "${GIT_COMMAND}" branch -M main "${OUTPUT_REDIRECTION}"
		echo2stdout "${BOLD}${GREEN}Done.${RESET}"
	fi

	if kicad_setup "${TARGET_TEMPLATE}"; then exit 8; fi

	if add_library acheron_Symbols "${NO_GIT_SUBMODULE}" 0; then exit 9; fi

	if add_library acheron_Components "${NO_GIT_SUBMODULE}" 1; then exit 10; fi
	if add_library acheron_Connectors "${NO_GIT_SUBMODULE}" 1; then exit 11; fi
	if add_library acheron_Hardware "${NO_GIT_SUBMODULE}" 1; then exit 12; fi
	if add_library "acheron_${SWITCHTYPE}" "${NO_GIT_SUBMODULE}" 1; then exit 13; fi

	if [[ "${NOGRAPHICS}" -eq 0 ]]; then
		if add_library acheron_Graphics "${NO_GIT_SUBMODULE}" 1; then exit 14; fi
	fi

	if [[ "${NOLOGOS}" -eq 0 ]]; then
		if add_library acheron_Logo "${NO_GIT_SUBMODULE}" 1; then exit 15; fi
	fi

	if [[ "${NO3D}" -eq 0 ]]; then
		if add_library acheron_3D "${NO_GIT_SUBMODULE}" 1; then exit 16; fi
	fi

	if [[ "${LOCAL_CLEANCREATE}" -eq 1 ]]; then
		echo2stdout -e "${BOLD}${YELLOW}>>${WHITE} Cleaning up... ${RESET}\c"
		eval "${TRASH_COMMAND}" ./keyboard_create.sh ./*_template "${OUTPUT_REDIRECTION}"
		echo2stdout "${BOLD}${GREEN} Done.${RESET}"
	fi

	exit 0
}
#}}}1

# Parsing options and arguments --------------------------------------------------------------- {{{1
while (( "$#" )); do
	case $1 in
	# HANDLING ARGUMENTS ---------------------
		-h | --help)
			usage
			exit 0
			;;
		-v | --verbose)
			VERBOSE=1
			OUTPUT_REDIRECTION=
			;;
		-cc | --cleancreate)
			CLEANCREATE=1
			;;
		-nl | --nologos)
			NOLOGOS=1
			;;
		-ng | --nographics)
			NOGRAPHICS=1
			;;
		-n3 | --no3d)
			NO3D=1
			;;
		-nr | --norepo)
			NO_GIT_REPO=1
			;;
		-ns | --nosubmodule)
			NO_GIT_SUBMODULES=1
			;;
		-pc | --purgeclean)
			PURGECLEAN=1
			;;
	# HANDLING OPTIONS -----------------------
		# TEMPLATE ARGUMENT --------------
		-t | --template)
			TEMPLATE="$2"
			shift
			;;
		--template=?*)
			TEMPLATE=${1#*=} # Deletes everything up to "=" and assigns the remainder
			;;
		# KICADDIR ARGUMENT --------------
		-kd | --kicaddir)
			KICADDIR="$2"
			shift
			;;
		--kicaddir=?*)
			KICADDIR=${1#*=} # Deletes everything up to "=" and assigns the remainder
			;;
		# LIBDIR ARGUMENT ----------------
		-ld | --libdir)
			LIBDIR="$2"
			shift
			;;
		--libdir=?*)
			LIBDIR=${1#*=} # Deletes everything up to "=" and assigns the remainder
			;;
		# PRJNAME ARGUMENT ----------------
		-p | --projectname)
			PRJNAME="$2"
			shift
			;;
		--projectname=?*)
			PRJNAME=${1#*=} # Deletes everything up to "=" and assigns the remainder
			;;
		# SWITCHTYPE ARGUMENT ----------------
		-s | --switchtype)
			SWITCHTYPE="$2"
			shift
			;;
		--switchtype=?*)
			SWITCHTYPE=${1#*=} # Deletes everything up to "=" and assigns the remainder
			;;
		*)
			echo2stderr "${BOLD}${RED}>> WARN: ${RESET} Unknown argument '$1'. Ignoring..."
	esac
	shift
done
#}}}1

# Check the correctness of the values read from stdin ----------------------------------------- {{{1
verbose_logging "${BOLD}>> INFO:  ${GREEN}Verbose logging enabled${RESET}"
verbose_logging "${BOLD}>> DEBUG: ${YELLOW}CLEANCREATE set to ${CLEANCREATE}${RESET}"
verbose_logging "${BOLD}>> DEBUG: ${YELLOW}NOLOGOS set to ${NOLOGOS}${RESET}"
verbose_logging "${BOLD}>> DEBUG: ${YELLOW}NOGRAPHICS set to ${NOGRAPHICS}${RESET}"
verbose_logging "${BOLD}>> DEBUG: ${YELLOW}NO3D set to ${NO3D}${RESET}"
verbose_logging "${BOLD}>> DEBUG: ${YELLOW}NO_GIT_REPO set to ${NO_GIT_REPO}${RESET}"
verbose_logging "${BOLD}>> DEBUG: ${YELLOW}NO_GIT_SUBMODULES set to ${NO_GIT_SUBMODULES}${RESET}"
verbose_logging "${BOLD}>> DEBUG: ${YELLOW}PURGECLEAN set to ${PURGECLEAN}${RESET}"
verbose_logging "${BOLD}>> DEBUG: ${YELLOW}TEMPLATE set to ${TEMPLATE}${RESET}"
verbose_logging "${BOLD}>> DEBUG: ${YELLOW}KICADDIR set to ${KICADDIR}${RESET}"
verbose_logging "${BOLD}>> DEBUG: ${YELLOW}LIBDIR set to ${LIBDIR}${RESET}"
verbose_logging "${BOLD}>> DEBUG: ${YELLOW}PRJNAME set to ${PRJNAME}${RESET}"
verbose_logging "${BOLD}>> DEBUG: ${YELLOW}SWITCHTYPE set to ${SWITCHTYPE}${RESET}"

if [[ -z "${TEMPLATE}" ]]; then
	echo2stderr "${BOLD}${RED}>> ERROR:${RESET} -t/--template argument requires a non-empty string."
	exit 1
fi

if [[ -z "${KICADDIR}" ]]; then
	echo2stderr "${BOLD}${RED}>> ERROR:${RESET} -kd/--kicaddir argument requires a non-empty string."
	exit 2
fi

if [[ -z "${LIBDIR}" ]]; then
	echo2stderr "${BOLD}${RED}>> ERROR:${RESET} -ld/--libdir argument requires a non-empty string."
	exit 3
fi

if [[ -z "${PRJNAME}" ]]; then
	echo2stderr "${BOLD}${RED}>> ERROR:${RESET} -p/--projectname requires a non-empty string."
	exit 4
fi
#}}}1

# Checking if the limited options are in the allowed values ----------------------------------- {{{1
if [[ ! ${ALLOWED_SWITCHTYPES[*]} =~ (^|[[:space:]])"${SWITCHTYPE}"($|[[:space:]]) ]]; then
	echo2stderr "${BOLD}${RED}>> ERROR:${WHITE} switch type option '${SWITCHTYPE}' is not recognized. Run the script with the '-h' option for usage guidelines.${RESET}"
	exit 5
fi

if [[ ! ${ALLOWED_TEMPLATES[*]} =~ (^|[[:space:]])"${TEMPLATE}"($|[[:space:]]) ]]; then
	echo2stderr "${BOLD}${RED}>> ERROR:${WHITE} template option '${TEMPLATE}' is not recognized. Run the script with the '-h' option for usage guidelines.${RESET}"
	exit 6
fi
#}}}1

main "${TEMPLATE}" "${NOGRAPHICS}" "${NOLOGOS}" "${NO3D}" "${CLEANCREATE}" "${NO_GIT_REPO}" "${NO_GIT_SUBMODULES}" "${PURGECLEAN}" "${SWITCHTYPE}"
