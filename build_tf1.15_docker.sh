#!/bin/bash

WORKING_DIR=$(eval pwd)

TF_VERSION=1.15
#PYTHON_VERSION=python3.6
JOBS=8
local_ram_resources=8000

DOCKER_TAG=tf-nv-gpu:$TF_VERSION

TF_CUDA_COMPUTE_CAPABILITIES="5.0"
CC_OPT_FLAGS="-march=westmere -Wno-sign-compare"

TF_DIR=src/nv_tensorflow_src

if [[ -d "$TF_DIR" ]]
then
    echo "$TF_DIR already exists."
else
		mkdir $TF_DIR --parents
		git clone https://github.com/tensorflow/tensorflow $TF_DIR
fi

cd $TF_DIR/tensorflow/tools/dockerfiles
git pull
git checkout r$TF_VERSION

docker build -f ./dockerfiles/devel-gpu.Dockerfile --build-arg CHECKOUT_TF_SRC=0 -t $DOCKER_TAG .

# open main dir again
cd $WORKING_DIR

WHEELS_DIR=$WORKING_DIR/wheels

if [[ -d "$WHEELS_DIR" ]]
then
    echo "$WHEELS_DIR already exists."
else
		mkdir $WHEELS_DIR --parents
fi


docker run -m 14G -d -it --rm -w / -v $WHEELS_DIR:/mnt -e HOST_PERMS="$(id -u):$(id -g)" --name tf_build $DOCKER_TAG bash

DOCKER_WORKING_DIR=/
DOCKER_EXEC="docker exec -it -w $DOCKER_WORKING_DIR tf_build bash -c "

echo Cloneing TF Repo
$DOCKER_EXEC "git clone https://github.com/NVIDIA/tensorflow tensorflow_src"

DOCKER_WORKING_DIR=/tensorflow_src
DOCKER_EXEC="docker exec -it -w $DOCKER_WORKING_DIR tf_build bash -c "

echo pull repo
$DOCKER_EXEC "git pull"
echo Checkout correct branch
$DOCKER_EXEC "git checkout r$TF_VERSION"
$DOCKER_EXEC "CC_OPT_FLAGS=\"$CC_OPT_FLAGS\" TF_CUDA_COMPUTE_CAPABILITIES=\"$TF_CUDA_COMPUTE_CAPABILITIES\"  ./configure"
$DOCKER_EXEC "bazel build --config=cuda --config=opt --local_ram_resources=$local_ram_resources --jobs=$JOBS //tensorflow/tools/pip_package:build_pip_package && ./bazel-bin/tensorflow/tools/pip_package/build_pip_package /mnt && chown \$HOST_PERMS /mnt/tensorflow-*.whl"

docker stop tf_build


