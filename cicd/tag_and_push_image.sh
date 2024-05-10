#!/bin/bash
# Tag images and push them to the registry

if [ -z "$1" ]; then
    echo 'Source image [full] ($1) is required'
    exit 1
fi

if [ -z "$2" ]; then
    echo 'Output base image ID [no tags] ($2) is required'
    exit 1
fi

set -xeuo pipefail

function tag_and_push {
    docker tag "${SOURCE_IMAGE}" "${OUTPUT_BASE_IMAGE}:${1}"
    echo "********** Pushing ${OUTPUT_BASE_IMAGE}:${1}"
    docker push "${OUTPUT_BASE_IMAGE}:${1}"
    echo "**********"
}
    
SOURCE_IMAGE="${1}"
OUTPUT_BASE_IMAGE="${2}"

IMAGE_LABELS_JSON=$(docker inspect tjnii-sandbox/tun_mesh:current-build | jq '.[0].Config.Labels' -ce)
SEMVER_FULL=$(echo "${IMAGE_LABELS_JSON}" | jq -re '."com.f5.tun_mesh.version"')
REPO_CLEAN=$(echo "${IMAGE_LABELS_JSON}" | jq -re '."com.f5.tun_mesh.repo_clean"')
              
# Following the same basic conventions as Alpine
tag_and_push "${SEMVER_FULL}"
tag_and_push "edge"

if [ ${REPO_CLEAN} != true ]; then
    echo "Unclean repo, not pushing bare semver and version major images"
    exit 0
fi

SEMVER_BARE=$(echo "${SEMVER_FULL}" | cut -f 1 -d -)
SEMVER_VERSION_MAJOR=$(echo "${SEMVER_BARE}" | cut -f 1 -d .)
SEMVER_VERSION_MINOR=$(echo "${SEMVER_BARE}" | cut -f 2 -d .)

tag_and_push "${SEMVER_BARE}"
tag_and_push "${SEMVER_VERSION_MAJOR}.${SEMVER_VERSION_MINOR}"
tag_and_push "${SEMVER_VERSION_MAJOR}"
tag_and_push "latest"

exit 0
