#!/bin/bash

#------------------------------------------------------------------------------
# Initialization
#------------------------------------------------------------------------------

[[ -n "${__stdlib_sourced:+'True'}" ]] && return 0

# Setting the 'strict' mode on by default
# Disable some of the options if it is really neccessary
set -euo pipefail
IFS=$'\n\t'

LANG="C.UTF-8"
LC_ALL="C.UTF-8"


# Exit-codes:
declare -ri SUCCESS=0
declare -ri FAILURE=1


#------------------------------------------------------------------------------
# Booleans
#------------------------------------------------------------------------------

declare -ri TRUE=1
declare -ri FALSE=0


function isBool() {
    local value="${1:-}"

    [[ "${value}" == "${TRUE}" || "${value}" == "${FALSE}" ]] && return ${SUCCESS}

    value="${value,,}"
    [[
        "${value}" =~ ^(0|1)$               ||
        "${value}" =~ ^(true|t|false|f)$    ||
        "${value}" =~ ^(yes|y|no|n)$        ||
        "${value}" =~ ^(on|off)$
    ]] && return ${SUCCESS}
        
    return ${FAILURE}
}


function isTrue() {
    local value="${1:-}"

    isBool "${value}" || return ${FAILURE}

    [[ "${value}" == "${TRUE}" ]] && return ${SUCCESS}

    value="${value,,}"
    [[
        "${value}" == '1'           ||
        "${value}" =~ ^(true|t)$    ||
        "${value}" =~ ^(yes|y)$     ||
        "${value}" =~ ^(on)$
    ]] && return ${SUCCESS}
        
    return ${FAILURE}
}

function isFalse() { isBool "${1:-}" && ! isTrue "${1:-}"; }


#------------------------------------------------------------------------------
# Loging
#------------------------------------------------------------------------------

declare -rA _LOG_LEVELS=(
    [FATAL]=0
    [ERROR]=1
    [WARNING]=2
    [INFO]=3
    [DEBUG]=4
)

declare -i _LOG_LEVEL="${_LOG_LEVELS[INFO]}"


function _print_log() {
    # Usage: _print_log LOG_LEVEL [MESSAGE]
    # private log-printing function, not for regular usage!

    local -r s_message_level="${1:-"ERROR"}"; shift
    local -r message="${*:-"EMPTY MESSAGE"}"

    local -ri i_message_level="${_LOG_LEVELS["${s_message_level}"]:-1}"
    local -ri log_level="${_LOG_LEVEL:-3}"
    
    if [[ ${i_message_level} -le ${log_level} ]]; then
        local -r caller="$( realpath -esq --relative-to="${PWD}" "${BASH_SOURCE[2]:-.}" 2>/dev/null )"
        printf '%-9s%s' "${s_message_level}" "${caller}:${BASH_LINENO[1]:-}  "
        printf '%s\n' "${message}"
    fi

    return ${SUCCESS}
}


function log_fatal()   { _print_log 'FATAL'   "$@"; }
function log_error()   { _print_log 'ERROR'   "$@"; }
function log_warning() { _print_log 'WARNING' "$@"; }
function log_info()    { _print_log 'INFO'    "$@"; }
function log_debug()   { _print_log 'DEBUG'   "$@"; }
function log_enter()   { _print_log 'DEBUG'   "Entering function '${FUNCNAME[1]:-}'"; }
function log_leave()   { _print_log 'DEBUG'   "Leaving  function '${FUNCNAME[1]:-}'"; }


function set_log_level() {
    # Usage: set_log_level [FATAL|ERROR|WARNING|INFO|DEBUG]
    local -r s_level="${1:-"INFO"}"
    local    i_level="${_LOG_LEVELS["${s_level}"]:-}"

    [[ -z "${i_level}" ]] && {
        log_warning "Unknown log level '$s_level'. Setting to 'INFO'"
        i_level="${_LOG_LEVELS[INFO]:-3}"
    }
    
    _LOG_LEVEL="${i_level}"

    return ${SUCCESS}
}


#------------------------------------------------------------------------------
# Messaging (print despite the loging level set)
#------------------------------------------------------------------------------

function _print() {
    # Usage: _print MESSAGE_TYPE [-b|-c 'COLOR'] [MESSAGE]
    # private message-printing function, not for regular use!

    local    color_on=''
    local -r color_off='\033[0m'

    local -r message_type=${1:-"ERROR"}; shift

    if [[ "${1:-}" == '-b' ]]; then
        color_on='\033[1m'
        shift
    elif [[ "${1:-}" == '-c' ]]; then
        color_on="${2:-\033[1m}"
        shift 2
    fi

    local -r message="${*:-"EMPTY MESSAGE"}"

    [[ -n "${color_on}" ]] && printf "${color_on}" 
    printf '%-9s%s\n' "${message_type}" "${message}"
    [[ -n "${color_on}" ]] && printf "${color_off}"

    return ${SUCCESS}
}


function print_info()    { _print 'INFO'       "$@"; }
function print_error()   { _print 'ERROR'      "$@"; }
function print_warning() { _print 'WARNING'    "$@"; }
function print_success() { _print 'SUCCESS'    "$@"; }
function print_failure() { _print 'FAILURE'    "$@"; }
function print_message() { _print '#######' -b "$@"; }


#------------------------------------------------------------------------------
# Error handling
#------------------------------------------------------------------------------

function log_if_error() {
    # print a message and returns an exit code of the previous command
    # Usage: log_if_error [ERROR MESSAGE]
    
    local -ri last_exit_code=${?:-1}    
    local -r  message="${*:-"SOMETHING WRONG"}"
    
    [[ ${last_exit_code} -ne 0 ]] && log_error "${message}"
    
    return ${last_exit_code}
}


function exit_if_error() {
    # print a message and exit
    # Usage: exit_if_error [EXIT MESSAGE]
    
    local -ri last_exit_code=${?:-1}    
    local -r  message="${*:-"SOMETHING WRONG"}"
    
    if [[ ${last_exit_code} -ne 0 ]]; then
        _print_log 'FATAL' "${message}"
        exit ${last_exit_code}
    fi
    
    return ${last_exit_code}
}

#------------------------------------------------------------------------------
# Validation functions
#------------------------------------------------------------------------------

function isValid() {
    # Usage: isValid VALUE [-v 'VALIDATOR']
    
    local -r value="${1:-}"
    local -r pattern="${3:-"^[[:graph:][:blank:]]*$"}"

    if [[ $# -eq 2 || ( $# -eq 3 && "${2:-}" != '-v' ) ]]; then
        log_error "$( echo -e "Wrong input: '$*'.\nUsage: isValid VALUE [-v 'VALIDATOR']" )"
        return ${FAILURE}
    fi
    
    if [[ "${pattern}" =~ ^[^[:graph:]]*$ || \
        ! "${pattern}" =~ ^[[:print:]]+$ ]]; then
        log_error "Wrong formatted validator '${pattern}'"
        return ${FAILURE}
    fi

    [[ "${value}" =~ ${pattern} ]] && return ${SUCCESS}

    return ${FAILURE}
}

function isBlank()      { isValid "${1:-}" && isValid "${1:-}" -v '^[[:blank:]]*$'; }
function isEmpty()      { [[ -z "${1:-}" ]]; }


#------------------------------------------------------------------------------
# Parsing options
#------------------------------------------------------------------------------

function isValidKey()   { isValid "${1:-}" -v '^(-[[:alnum:]]|--[[:alnum:]]+[-_[:alnum:]]*)$'; }

function read_options() {
    local -n options="${1:-}"; shift
    local -A -p options &> /dev/null || {
        log_fatal "WRONG INPUT. Usage: ${FUNCNAME[0]} OPTIONS [ INPUT ARGS ]"
        return ${FAILURE}
    }

    local -i status=SUCCESS
    local key value

    while [[ $# -gt 0 ]]; do
        if ! isValidKey "$1"; then
            log_error "Invalid option key '$1'"
            status=FAILURE
            shift
            continue
        fi

        key="$1"; shift
        value=""
        ! isValidKey "${1:-}" && { value="${1:-}"; shift; }

        if ! isValid "${value}"; then
            log_error "Invalid value '${value}' for key '${key}'"
            status=FAILURE
            continue
        fi

        options["${key}"]="${value}"
    done

    return ${status}
}


function validate_options() {
    # shellcheck disable=SC2178
    local -n options="${1:-}"
    local validation_function="${2:-}"
    if ! local -A -p options &> /dev/null || \
        [[ "$( type -t "${validation_function}" )" != "function" ]]; then
        log_fatal "WRONG INPUT. Usage: ${FUNCNAME[0]} OPTIONS VALIDATOR"
        return ${FAILURE}
    fi

    local -i status=SUCCESS
    
    local value
    for key in "${!options[@]}"; do
        value="${options["${key}"]}"

        # shellcheck disable=SC2154
        ${validation_function} "${key}" "${value}" || status=FAILURE
    done

    return ${status}
}


__stdlib_sourced="${TRUE}"
