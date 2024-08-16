#!/bin/bash

git clone https://github.com/feliks912/vastai_houdini/ /repo

chmod +x /repo/docker/*.sh || echo "Can't chmod the scripts in docker/*"

bash /repo/docker/repo_entrypoint.sh
