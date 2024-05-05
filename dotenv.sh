#!/bin/bash


#------------------------------------------------------------------------------
# Initialization
#------------------------------------------------------------------------------

[[ -n "${__dotenv_sourced:+'True'}" ]] && return 0

__dotenv_path="$( readlink -e "$( dirname "${BASH_SOURCE[0]}" )" )"
readonly __dotenv_path

source "${__dotenv_path}/stdlib.sh" || {
    echo "Error: Failed to load 'stdlib.sh'"
    return 1
}


#------------------------------------------------------------------------------
# Function: read_env
# Usage: read_env ENV_FILE [--overwrite]
#
# This function reads environment variables from .env files.
# The file should have plain KEY='VALUE' format.
# It is assumed that .env files can be used in some Python apps
# using the django-environ package, which does not support value interpolation.
# Therefore, to maintain consistency with Python apps, all values will be interpreted
# as single-quoted strings, regardless of how the values are specified in the file.
# Any comments and blank lines are omitted.
#
# Arguments:
#    ENV_FILE: The target env-file (both absolute or relative path can be used).
# --overwrite: (optional) If provided, variables that are already
#              defined in the environment will be overwritten with the values
#              from the ENV_FILE.
#
# Example:
#   read_env .env --overwrite
#------------------------------------------------------------------------------

function read_env () {
    local env_file="${1:-}"
    log_debug "Reading variables from '${env_file}'"

    [[ -f "${env_file}" ]] || {
        log_debug "File '${env_file}' not found"
        return "${FAILURE}"
    }

    local overwrite="${FALSE}"
    [[ "${2:-}" == '--overwrite' ]] && overwrite="${TRUE}"

    local variable
    local value

    while read -r key_val_pair; do
        variable="${key_val_pair/%=*}"
        value="${key_val_pair#*=}"
        value="$( echo "${value}" | sed -e "s/^['\"]*//" -e "s/['\"]*$//" )"
        
        if [[ -v "${variable}" ]]; then
            if isTrue "${overwrite}"; then
                log_debug "Rewriting already defined '${variable}'. Old value: '${!variable}'"
                unset "${variable}"
            else
                log_debug "Skipping already defined '${variable}' with value: '${!variable}'"
                continue
            fi
        else
            log_debug "Declaring new variable '${variable}'"
        fi

        log_debug "${variable}=${value}"
        declare -xg "${variable}=${value}"
    done <<< "$( grep -E '^[a-zA-Z_]+[a-zA-Z0-9_]*=[[:print:]]*$' "${env_file}" )"

    return "${SUCCESS}"
}


__dotenv_sourced="${TRUE}"
