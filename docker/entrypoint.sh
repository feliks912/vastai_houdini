#!/bin/bash

git clone https://github.com/feliks912/vastai_houdini/ /repo

chmod +x /repo/docker/repo_entrypoint.sh || echo "Can't chmod repo_entrypoint in /repo/docker/"

bash /repo/docker/repo_entrypoint.sh
