#!/usr/bin/env sh

#SBATCH --job-name=mlperf-inference-text-to-image-stable-diffusion-xl-python-datacenter-pytorch-cuda
#SBATCH --account=ddp324
#SBATCH --clusters=expanse
#SBATCH --partition=gpu-shared
#SBATCH --gpus=1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=92G
#SBATCH --time=01:00:00
#SBATCH --output=logs/%x.o%A.%a.%N
#SBATCH --array=0

set -euo pipefail

declare -xir UNIX_TIME="$(date +'%s')"
declare -xr LOCAL_TIME="$(date +'%Y%m%dT%H%M%S%z')"

declare -xr SLURM_JOB_SCRIPT="$(scontrol show job ${SLURM_JOB_ID} | awk -F= '/Command=/{print $2}')"
declare -xr SLURM_JOB_SCRIPT_MD5="$(md5sum ${SLURM_JOB_SCRIPT} | awk '{print $1}')"
declare -xr SLURM_JOB_SCRIPT_SHA256="$(sha256sum ${SLURM_JOB_SCRIPT} | awk '{print $1}')"
declare -xr SLURM_JOB_SCRIPT_NUMBER_OF_LINES="$(wc -l ${SLURM_JOB_SCRIPT} | awk '{print $1}')"

declare -xr LUSTRE_PROJECT_DIR="/expanse/lustre/projects/${SLURM_JOB_ACCOUNT}/${USER}"
declare -xr LUSTRE_SCRATCH_DIR="/expanse/lustre/scratch/${USER}/temp_project"
declare -xr LOCAL_SCRATCH_DIR="/scratch/${USER}/job_${SLURM_JOB_ID}"
declare -xr CEPH_USER_DIR="/expanse/ceph/users/${USER}"

declare -xr CONDA_CACHE_DIR="${SLURM_SUBMIT_DIR}"
declare -xr CONDA_ENV_YAML="${CONDA_CACHE_DIR}/mlperf-inference-text-to-image-stable-diffusion-xl-python-datacenter-pytorch-cuda.yaml"
declare -xr CONDA_ENV_NAME="$(grep '^name:' ${CONDA_ENV_YAML} | awk '{print $2}')"

echo "${UNIX_TIME} ${LOCAL_TIME} ${SLURM_JOB_ID} ${SLURM_ARRAY_JOB_ID} ${SLURM_ARRAY_TASK_ID} ${SLURM_JOB_SCRIPT_MD5} ${SLURM_JOB_SCRIPT_SHA256} ${SLURM_JOB_SCRIPT_NUMBER_OF_LINES}"
cat "${SLURM_JOB_SCRIPT}"

module purge
module list

cd "${LOCAL_SCRATCH_DIR}"

if [[ -f "${CONDA_ENV_YAML}.md5" ]] && md5sum -c "${CONDA_ENV_YAML}.md5"; then
    
    echo "Unpacking existing the conda environment to ${LOCAL_SCRATCH_DIR} ..."
    cp "${CONDA_CACHE_DIR}/${CONDA_ENV_NAME}.tar.gz" ./
    tar -xf "${CONDA_ENV_NAME}.tar.gz"
    
    set +u  # conda crashes without this
    source bin/activate
    conda-unpack
    set -u
    
else
    
    export CONDA_INSTALL_PATH="${LOCAL_SCRATCH_DIR}/miniconda3"
    export CONDA_ENVS_PATH="${CONDA_INSTALL_PATH}/envs"
    export CONDA_PKGS_DIRS="${CONDA_INSTALL_PATH}/pkgs"
    
    if [[ -f "${HOME}/Miniconda3-latest-Linux-x86_64.sh" ]]; then
        echo "Using existing miniconda installer from ${HOME} ..."
        export CONDA_INSTALLER_SCRIPT="${HOME}/Miniconda3-latest-Linux-x86_64.sh"
    else
        echo "Installing miniconda to ${LOCAL_SCRATCH_DIR} ..."
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
        chmod +x Miniconda3-latest-Linux-x86_64.sh
        export CONDA_INSTALLER_SCRIPT="./Miniconda3-latest-Linux-x86_64.sh"
    fi
    "${CONDA_INSTALLER_SCRIPT}" -b -p "${CONDA_INSTALL_PATH}"
    
    echo "Re/building the conda environment from ${CONDA_ENV_YAML} ..."
    source "${CONDA_INSTALL_PATH}/etc/profile.d/conda.sh"
    conda activate base
    conda install -y mamba -n base -c conda-forge
    mamba env create --file "${CONDA_ENV_YAML}"
    conda install -y conda-pack
    
    echo "Packing the conda environment and caching it to ${CONDA_CACHE_DIR} ..."
    conda pack -n "${CONDA_ENV_NAME}" -o "${CONDA_ENV_NAME}.tar.gz"
    cp "${CONDA_ENV_NAME}.tar.gz" "${CONDA_CACHE_DIR}/${CONDA_ENV_NAME}.tar.gz"
    md5sum "${CONDA_ENV_YAML}" > "${CONDA_ENV_YAML}.md5"
    
    set +u  # conda crashes without this
    conda activate "${CONDA_ENV_NAME}"
    set -u
    
fi

echo "Finalizing the software environment configuration ..."

echo "Setting up MLCFlow ..."
export MLC_REPOS="${LOCAL_SCRATCH_DIR}/MLC/repos"
pip install mlcflow
pip install mlc-scripts
mlc pull repo mlcommons@mlperf-automations --branch=main
mlc run script --tags="get,python,python3,get-python,get-python3,_custom-path.$(which python)"

echo "Downloading SDXL model ..."
# If SDXL_MODEL_DIR exists, this will tell MLCFlow to use the model from there.
export SDXL_MODEL_DIR="${HOME}/sdxl_cache/model_fp16"
mlc run script --tags="get,ml-model,sdxl,_pytorch,_fp16,_rclone" --checkpoint="${SDXL_MODEL_DIR}"

echo "Downloading dataset ..."
# TODO: cache dataset too
mlc run script --tags="get,dataset,coco2014,_validation,_full"

printenv

echo "Running the inference benchmark ..."
mlcr run-mlperf,inference,_full,_r5.0-dev \
--model=sdxl \
--precision=float16 \
--implementation=reference \
--framework=pytorch \
--category=datacenter \
--scenario=Offline \
--execution_mode=valid \
--device=cuda \
--quiet

sleep 6000
