#!/bin/bash

git clone https://github.com/feliks912/vastai_houdini/ /repo

cd /repo || echo "Can't cd to /repo"

chmod +x ./**

bash /repo/docker/repo_entrypoint.sh
