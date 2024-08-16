#!/bin/bash

docker login -u feliks912 -p kM55Zcau!

apt update && apt install aria2 -y

aria2c -x 4 -s 4 -d /tmp -o houdini20_precracked.tar.gz \
"https://huggingface.co/feliks912/Houdini_cracked_lin/resolve/main/houdini-py39-20.0.547-linux_x86_64_gcc11.2_PRECRACKED.tar.gz?download=true"

 # cd into the bundle and use relative paths
if [[ "$BASH_SOURCE" = */* ]]; then
     cd -- "${BASH_SOURCE%/*}/" || exit
else
  echo "Error when cd-ing to BASH_SOURCE. exiting build script"
  exit 1
fi

docker build -t houdini20.0_cuda12.2_dind -f Dockerfile_remote .
docker tag houdini20.0_cuda12.2 feliks912/houdini20.0_cuda12.2_dind:latest
docker push feliks912/houdini20.0_cuda12.2_dind:latest