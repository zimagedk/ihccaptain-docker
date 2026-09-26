#!/usr/bin/env bash

podman images prune >/dev/null

while read -r img; do
    podman rmi "${img}" >/dev/null || true
done < <(podman images --filter "dangling=true" --format '{{.ID}}')
