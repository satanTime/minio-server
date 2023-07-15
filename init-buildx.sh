#!/bin/bash

docker buildx create --use --bootstrap \
  --name minio-server \
  --driver docker-container \
  --config ./init-buildx.toml
