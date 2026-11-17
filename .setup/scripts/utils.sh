#!/usr/bin/env bash
#ddev-generated
# Helpers for the commands of the wordpress-multi-version-plugin add-on,
# sourced in the web container from the project root.

# Verbose flag — set VERBOSE=1 (or pass -v/--verbose to `ddev install`) to
# disable the spinner and stream all command output live.
VERBOSE="${VERBOSE:-0}"

# Internal state shared between _progress, _done and _progress_exit_trap.
SPINNER_PID=0
PROGRESS_ACTIVE=0
PROGRESS_LOG=""
PROGRESS_LABEL=""

# Function to display a spinner at the current cursor position (simple colored style)
function _spinner() {
    local chars="|/-\\"
    local delay=0.1
    local i=0

    while true; do
        printf "\b\e[36m%c\e[0m" "${chars:$i:1}"
        ((i++))
        if [ $i -eq ${#chars} ]; then
            i=0
        fi
        sleep $delay
    done
}

function _progress() {
    PROGRESS_LABEL="$1"
    printf "%s... " "$1"
    # Spinner mode only in interactive terminals outside CI and verbose runs.
    if [[ "$VERBOSE" -eq 0 ]] && [[ -z "$CI" ]] && [[ -z "$GITHUB_ACTIONS" ]] && [[ -z "$GITLAB_CI" ]] && [[ -z "$JENKINS_URL" ]] && [[ -t 1 ]]; then
      PROGRESS_LOG="$(mktemp)"
      printf " "
      _spinner &
      SPINNER_PID=$!
      # Save stdout/stderr, capture command output to a logfile so we can
      # replay it on failure instead of swallowing it into /dev/null.
      exec 3>&1 4>&2
      exec >"$PROGRESS_LOG" 2>&1
      PROGRESS_ACTIVE=1
    else
      PROGRESS_LOG=""
      printf "\n"
    fi
}

# Stop the spinner (if running) and restore the original stdout/stderr file
# descriptors. Idempotent — safe to call when no progress region is active.
function _stop_spinner() {
    [ $PROGRESS_ACTIVE -eq 1 ] || return 0
    kill $SPINNER_PID 2>/dev/null || true
    wait $SPINNER_PID 2>/dev/null || true
    SPINNER_PID=0
    exec 1>&3 2>&4
    PROGRESS_ACTIVE=0
}

# Replay the captured progress log to the user's terminal, then remove it.
# No-op when there is no logfile (verbose / non-interactive mode).
function _replay_progress_log() {
    [ -n "$PROGRESS_LOG" ] && [ -f "$PROGRESS_LOG" ] || return 0
    message red "--- Captured output (${PROGRESS_LABEL# }) ---"
    cat "$PROGRESS_LOG"
    message red "--- End of captured output ---"
    rm -f "$PROGRESS_LOG"
    PROGRESS_LOG=""
}

# Discard the captured progress log without replaying it (success path).
function _clear_progress_log() {
    [ -n "$PROGRESS_LOG" ] && [ -f "$PROGRESS_LOG" ] || return 0
    rm -f "$PROGRESS_LOG"
    PROGRESS_LOG=""
}

function _done() {
    local rc=$?
    local had_spinner=$PROGRESS_ACTIVE
    _stop_spinner

    if [ $rc -ne 0 ]; then
      if [ $had_spinner -eq 1 ]; then
        printf "\b\e[0m\e[31m✘\e[39m\n"
      else
        printf "\e[31m✘\e[39m\n"
      fi
      _replay_progress_log
      exit $rc
    fi

    if [ $had_spinner -eq 1 ]; then
      printf "\b\e[0m\e[32m✔\e[39m\n"
    else
      printf "\e[32m✔\e[39m\n"
    fi
    _clear_progress_log
}

# EXIT trap: surfaces errors from `set -e` aborts mid-block. Stops any running
# spinner, restores file descriptors, and dumps the captured log so the user
# sees the actual command output that failed.
function _progress_exit_trap() {
    [ $PROGRESS_ACTIVE -eq 1 ] || return 0
    _stop_spinner
    printf "\b\e[0m\e[31m✘\e[39m\n"
    _replay_progress_log
}
trap _progress_exit_trap EXIT

# WP_VERSIONS, validated: the labels become directory names that `ddev install` deletes
wp_versions() {
    local version
    for version in ${WP_VERSIONS:-}; do
        if ! [[ "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
            echo "Invalid WordPress version '$version' in WP_VERSIONS, use <major>.<minor>, e.g. 7.1." >&2
            return 1
        fi
        echo "$version"
    done
}

# Version -> hostname label and directory name, e.g. 7.1 -> 71
wp_label() {
    echo "${1//./}"
}

wp_path() {
    echo "/var/www/html/.Build/$(wp_label "$1")"
}

# The configured version matching a version (7.1) or a label (71)
wp_resolve() {
    local version versions
    versions=$(wp_versions) || return 1
    for version in $versions; do
        if [ "$1" = "$version" ] || [ "$1" = "$(wp_label "$version")" ]; then
            echo "$version"
            return 0
        fi
    done
    echo "Unknown WordPress version '$1', use one of: $(echo $versions)" >&2
    return 1
}

# Directory name composer/installers gives the plugin: extra.installer-name, else the package name without vendor
wp_plugin_slug() {
    local name
    name=$(jq -r '.extra["installer-name"] // .name // empty' /var/www/html/composer.json 2>/dev/null)
    if [ -z "$name" ]; then
        echo "No composer.json with a \"name\" in the project root." >&2
        return 1
    fi
    echo "${name##*/}"
}

wp_package_name() {
    jq -r '.name' /var/www/html/composer.json
}

message() {
    local color
    case "$1" in
        red) color=31 ;; green) color=32 ;; yellow) color=33 ;; blue) color=34 ;; magenta) color=35 ;; *) color=0 ;;
    esac
    printf "\e[%sm%s\e[0m\n" "$color" "$2"
}

# Sources .ddev/.setup/hooks/<name>.sh if the project has one. Sourced, so a hook sees
# $version, $label, $path, $url, $database, $multisite and $slug; from post-composer on
# it runs in the instance, where a plain `wp` works. A failing command aborts the install.
run_hook() {
    local hook_file="/var/www/html/.ddev/.setup/hooks/$1.sh"
    [ -f "$hook_file" ] || return 0
    _progress " ├─ Hook: $1"
        . "$hook_file"
    _done
}

# Defaults for `ddev install`; the project's .ddev/.setup/project.sh overrides them
THEME_PACKAGES=('wpackagist-theme/twentytwentyfour')
THEME='twentytwentyfour'
ADDITIONAL_PACKAGES=()
COMPOSER_CONFIG=()
FIXTURE_PACKAGE_DIRS=('Tests/Acceptance/Fixtures/packages')
if [ -f /var/www/html/.ddev/.setup/project.sh ]; then
    . /var/www/html/.ddev/.setup/project.sh
fi
