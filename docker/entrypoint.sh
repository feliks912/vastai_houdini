#!/bin/bash

git clone https://github.com/feliks912/vastai_houdini/ /repo

cd /repo || echo "Can't cd to /repo"

echo "$GIT_CRYPT_KEY" > /tmp/keyfile && git-crypt unlock /tmp/keyfile && rm /tmp/keyfile

chmod +x /repo/**

bash /repo/docker/repo_entrypoint.sh
