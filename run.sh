#!/bin/bash
# Testing script for running with Docker
set -e

docker build . -t mini_repo:latest
docker run \
  -e MINI_REPO_AUTH_TOKEN=secret \
  -e MINI_REPO_STORE_ROOT=/data \
  -v $PWD/data:/data \
  -v $PWD/config:/app/config \
  -p 4000:4000 \
  mini_repo:latest
