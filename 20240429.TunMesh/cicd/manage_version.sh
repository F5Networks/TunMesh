#!/bin/bash
# This is helper utility for bumping project release versions.
# Intended to be run interactively as part of PR generation.

set -euo pipefail

SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/_version_common.sh"

function show_help {
    echo "$0: Manage project version"
    echo "  -c: Show if repo is clean"
    echo "  -m: Increment minor"
    echo "  -M: Increment major"
    echo "  -s: Show current full version"
    echo ""
    echo "Patch, pre-release, and build are automatic."
    echo "Major/minor bumps are written to ${PRIMARY_VERSION_FILE} which needs to be comitted into the repo."
    exit 0
}

ACTION="default"

while getopts ":chMms" arg; do
    case $arg in
        h)
            show_help
            ;;
        c)
            echo "${REPO_CLEAN}"
            exit 0
            ;;
        s)
            echo "${SEMVER_FULL}"
            exit 0        
            ;;
        M)
            ACTION="inc_major"
            ;;
        m)
            ACTION="inc_minor"
            ;;
        *)
            echo "INTERNAL ERROR: option fallthrough"
            exit 1
            ;;
    esac
done

if [ $ACTION == default ]; then
    show_help
fi

if [ ${REPO_CLEAN} != true ]; then
    echo "ERROR: Repo git state is dirty"
    echo "Version automation is git sha based, cannot version uncomitted files."
    echo "Clean git state and retry."
    exit 1
fi

case $ACTION in
    inc_major)
        NEW_SEMVER_VERSION_MAJOR=$((${SEMVER_VERSION_MAJOR} + 1))
        NEW_SEMVER_VERSION_MINOR=0
        ;;
    inc_minor)
        NEW_SEMVER_VERSION_MAJOR=${SEMVER_VERSION_MAJOR}
        NEW_SEMVER_VERSION_MINOR=$((${SEMVER_VERSION_MINOR} + 1))
        ;;
    *)
        echo "INTERNAL ERROR: Action fallthrough"
        exit 1
        ;;
esac
    
SOURCE_GIT_SHA=$(git log  --pretty=format:"%H" -1 "${SOURCE_DIR}")
echo "Incrementing version MAJOR.MINOR from ${SEMVER_VERSION_MAJOR}.${SEMVER_VERSION_MINOR} to ${NEW_SEMVER_VERSION_MAJOR}.${NEW_SEMVER_VERSION_MINOR} on commit ${SOURCE_GIT_SHA}"
echo -e "${NEW_SEMVER_VERSION_MAJOR}.${NEW_SEMVER_VERSION_MINOR}\t${SOURCE_GIT_SHA}" >> "${PRIMARY_VERSION_FILE}"
exit 0


