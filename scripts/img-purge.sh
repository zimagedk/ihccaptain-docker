#!/usr/bin/env bash

podman images --prune

while read -r img; do
    podman rmi "${img}" || true
done < <(podman images --filter "dangling=true" --format '{{.ID}}')
