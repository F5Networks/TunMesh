#!/bin/bash
# Common version handling for ci/cd scripts
# https://semver.org/

set -euo pipefail

SCRIPT_DIR=$(dirname "$0")
SOURCE_DIR=$(dirname "${SCRIPT_DIR}")

if [ -n "$(git status -s "${SOURCE_DIR}")" ]; then
    SEMVER_PREFIXED_PRERELEASE="-dirty"
    REPO_CLEAN=false
else
    SEMVER_PREFIXED_PRERELEASE=""
    REPO_CLEAN=true
fi

PRIMARY_VERSION_FILE="${SOURCE_DIR}/Version"
if [ ! -f "${PRIMARY_VERSION_FILE}" ]; then
    echo >&2 "ERROR: Version file ${PRIMARY_VERSION_FILE} not found"
    echo "FAULT"
    exit 1
fi

BASE_VERSION=$(grep "^[0-9]\+\.[0-9]\+[[:space:]]\+[0-9a-f]\+$" "${PRIMARY_VERSION_FILE}" | tail -n 1)
SEMVER_VERSION_MAJOR=$(echo "$BASE_VERSION" | awk '{print $1}' | cut -f 1 -d .)
SEMVER_VERSION_MINOR=$(echo "$BASE_VERSION" | awk '{print $1}' | cut -f 2 -d .)
VERSION_LAST_SHA=$(echo "$BASE_VERSION" | awk '{print $2}')

# Patch is the count of commits since the last Version file line sha
# Grep is because git omits the trailing newline when outputting to a pipe, making it imposible to tell 0 commits from 1 with wc alone.
# The grep ensures each line has a newline.
SEMVER_VERSION_PATCH=$(git log --pretty=format:"%H" "${VERSION_LAST_SHA}".. "${SOURCE_DIR}" | grep . | wc -l)
SEMVER_VERSION_BUILD=$(date "+%s")

# Bare semver: Major/minor/patch only, no build/prerelease info
SEMVER_BARE="${SEMVER_VERSION_MAJOR}.${SEMVER_VERSION_MINOR}.${SEMVER_VERSION_PATCH}"
# NOTE: Deviating from semver as + is not legal in Docker tags
SEMVER_FULL="${SEMVER_BARE}${SEMVER_PREFIXED_PRERELEASE}-${SEMVER_VERSION_BUILD}"
