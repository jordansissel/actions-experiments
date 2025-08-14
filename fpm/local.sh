#!/bin/sh

docker buildx bake

# Show images
docker buildx bake --progress quiet --print  | jq -r ".target[].tags[0]" 