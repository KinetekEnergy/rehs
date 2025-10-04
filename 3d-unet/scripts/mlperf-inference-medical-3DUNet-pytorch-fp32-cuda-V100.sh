#!/usr/bin/env sh

#SBATCH --job-name=mlperf-inference-medical-3DUNet-pytorch-fp32-cuda-V100
#SBATCH --account=ddp324
#SBATCH --clusters=expanse
#SBATCH --partition=gpu-shared
#SBATCH --gpus=1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=92G
#SBATCH --time=24:00:00
#SBATCH --output=%x.o%A.%a.%N
#SBATCH --array=0

mode="a"

set -euo pipefail

# === TIME VARIABLES ===
declare -xir UNIX_TIME="$(date +'%s')"
declare -xr LOCAL_TIME="$(date +'%Y%m%dT%H%M%S%z')"

# === SLURM JOB VARIABLES ===
declare -xr SLURM_JOB_SCRIPT="$(scontrol show job ${SLURM_JOB_ID} | awk -F= '/Command=/{print $2}')"
declare -xr SLURM_JOB_SCRIPT_MD5="$(md5sum ${SLURM_JOB_SCRIPT} | awk '{print $1}')"
declare -xr SLURM_JOB_SCRIPT_SHA256="$(sha256sum ${SLURM_JOB_SCRIPT} | awk '{print $1}')"
declare -xr SLURM_JOB_SCRIPT_NUMBER_OF_LINES="$(wc -l ${SLURM_JOB_SCRIPT} | awk '{print $1}')"

# === PATHS ===
declare -xr LUSTRE_PROJECT_DIR="/expanse/lustre/projects/${SLURM_JOB_ACCOUNT}/${USER}"
declare -xr LUSTRE_SCRATCH_DIR="/expanse/lustre/scratch/${USER}/temp_project"
declare -xr LOCAL_SCRATCH_DIR="/scratch/${USER}/job_${SLURM_JOB_ID}"
declare -xr CEPH_USER_DIR="/expanse/ceph/users/${USER}"

# === CONDA ENV ===
declare -xr CONDA_CACHE_DIR="${SLURM_SUBMIT_DIR}"
declare -xr CONDA_ENV_YAML="${CONDA_CACHE_DIR}/mlcflow-dev.yaml"
declare -xr CONDA_ENV_NAME="$(grep '^name:' ${CONDA_ENV_YAML} | awk '{print $2}')"

# === CONFIRM VARIABLES ===
echo "[ OK ] Unix time: ${UNIX_TIME}"
echo "[ OK ] Local time: ${LOCAL_TIME}"
echo "[ OK ] Slurm job ID: ${SLURM_JOB_ID}"
echo "[ OK ] Slurm script MD5: ${SLURM_JOB_SCRIPT_MD5}"
echo "[ OK ] Slurm script SHA256: ${SLURM_JOB_SCRIPT_SHA256}"
echo "[ OK ] Script lines: ${SLURM_JOB_SCRIPT_NUMBER_OF_LINES}"
cat "${SLURM_JOB_SCRIPT}"

# === SETUP ENV ===
module purge
module list
cd "${LOCAL_SCRATCH_DIR}"

if [[ -f "${CONDA_ENV_YAML}.md5" ]] && md5sum -c "${CONDA_ENV_YAML}.md5"; then
    cp "${CONDA_CACHE_DIR}/${CONDA_ENV_NAME}.tar.gz" ./
    tar -xf "${CONDA_ENV_NAME}.tar.gz"
    set +u
    source bin/activate
    conda-unpack
    set -u
else
    export CONDA_INSTALL_PATH="${LOCAL_SCRATCH_DIR}/miniconda3"
    export CONDA_ENVS_PATH="${CONDA_INSTALL_PATH}/envs"
    export CONDA_PKGS_DIRS="${CONDA_INSTALL_PATH}/pkgs"

    if [[ -f "${HOME}/Miniconda3-latest-Linux-x86_64.sh" ]]; then
        export CONDA_INSTALLER_SCRIPT="${HOME}/Miniconda3-latest-Linux-x86_64.sh"
    else
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
        chmod +x Miniconda3-latest-Linux-x86_64.sh
        export CONDA_INSTALLER_SCRIPT="./Miniconda3-latest-Linux-x86_64.sh"
    fi

    "${CONDA_INSTALLER_SCRIPT}" -b -p "${CONDA_INSTALL_PATH}"
    source "${CONDA_INSTALL_PATH}/etc/profile.d/conda.sh"
    conda activate base
    conda install -y mamba -n base -c conda-forge
    mamba env create --file "${CONDA_ENV_YAML}"
    conda install -y conda-pack
    conda pack -n "${CONDA_ENV_NAME}" -o "${CONDA_ENV_NAME}.tar.gz"
    cp "${CONDA_ENV_NAME}.tar.gz" "${CONDA_CACHE_DIR}/${CONDA_ENV_NAME}.tar.gz"
    md5sum "${CONDA_ENV_YAML}" > "${CONDA_ENV_YAML}.md5"
    set +u
    conda activate "${CONDA_ENV_NAME}"
    set -u
fi

# === INSTALL MLCFLOW ===
echo "[ OK ] Installing MLCFlow"
pip install mlcflow mlc-scripts
mlc pull repo mlcommons@mlperf-automations --branch=main
mlc run script --tags="get,python,python3,get-python,get-python3,_custom-path.$(which python)"

# === DOWNLOAD 3DUNet MODEL ===
echo "[ OK ] Downloading 3DUNet model"
export MODEL_DIR="${HOME}/3dunet_cache/model_fp32"
mlc run script --tags="get,ml-model,3d-unet,_pytorch" --checkpoint="${MODEL_DIR}" --outdirname="${LOCAL_SCRATCH_DIR}" -j

# === DOWNLOAD DATASET ===
echo "[ OK ] Downloading KiTS19 validation and calibration datasets"
mlc run script --tags="get,ml-model,3d-unet,kits19" --outdirname="${LOCAL_SCRATCH_DIR}" -j


# === RUN BENCHMARK ===
printenv
echo "[ OK ] Running 3D-UNet inference benchmark"
mlcr run-mlperf,inference,_full,_r5.1-dev \
   --model=3d-unet-99 \
   --implementation=reference \
   --framework=pytorch \
   --category=edge \
   --scenario=Offline \
   --execution_mode=valid \
   --device=cuda \
   --quiet

sleep 6000

echo "[ OK ] Script finished"

