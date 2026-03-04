#!/usr/bin/env bash

TAG_BASE="zimagedk/ihccaptain"
VERSION=latest
PORT=9000

HERE="$(dirname "$(realpath $0)")"
DATA_FOLDER="${HERE}/run/podman"

mkdir -p "${DATA_FOLDER}"

podman run --rm -ti \
    -p "${PORT}:80" \
    -v "${DATA_FOLDER}:/app/data" \
    "${TAG_BASE}:${VERSION}"
