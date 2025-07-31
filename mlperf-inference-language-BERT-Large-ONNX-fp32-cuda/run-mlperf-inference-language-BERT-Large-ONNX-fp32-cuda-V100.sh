#!/usr/bin/env sh

#SBATCH --job-name=mlperf-inference-language-BERT-Large-ONNX-fp32-cuda-V100
#SBATCH --account=ddp324
#SBATCH --clusters=expanse
#SBATCH --partition=gpu-shared
#SBATCH --gpus=1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=92G
#SBATCH --time=48:00:00
#SBATCH --output=logs/%x.o%A.%a.%N
#SBATCH --array=0

mode="a"

set -euo pipefail

#####################################################
############### TIME VARIABLEs ######################
#####################################################

declare -xir UNIX_TIME="$(date +'%s')"
declare -xr LOCAL_TIME="$(date +'%Y%m%dT%H%M%S%z')"

#####################################################
############### SLURM JOB VARIABLES #################
#####################################################

declare -xr SLURM_JOB_SCRIPT="$(scontrol show job ${SLURM_JOB_ID} | awk -F= '/Command=/{print $2}')"
declare -xr SLURM_JOB_SCRIPT_MD5="$(md5sum ${SLURM_JOB_SCRIPT} | awk '{print $1}')"
declare -xr SLURM_JOB_SCRIPT_SHA256="$(sha256sum ${SLURM_JOB_SCRIPT} | awk '{print $1}')"
declare -xr SLURM_JOB_SCRIPT_NUMBER_OF_LINES="$(wc -l ${SLURM_JOB_SCRIPT} | awk '{print $1}')"

#####################################################
############### LUSTRE VARIABLES ####################
#####################################################

declare -xr LUSTRE_PROJECT_DIR="/expanse/lustre/projects/${SLURM_JOB_ACCOUNT}/${USER}"
declare -xr LUSTRE_SCRATCH_DIR="/expanse/lustre/scratch/${USER}/temp_project"
declare -xr LOCAL_SCRATCH_DIR="/scratch/${USER}/job_${SLURM_JOB_ID}"
declare -xr CEPH_USER_DIR="/expanse/ceph/users/${USER}"

#####################################################
############### CONDA VARIABLES #####################
#####################################################

declare -xr CONDA_CACHE_DIR="${SLURM_SUBMIT_DIR}"
declare -xr CONDA_ENV_YAML="${CONDA_CACHE_DIR}/mlperf-inference-language-BERT-Large-ONNX-fp32-cuda.yaml"
declare -xr CONDA_ENV_NAME="$(grep '^name:' ${CONDA_ENV_YAML} | awk '{print $2}')"

#####################################################
############### VARIABLE CONFIRMATION ###############
#####################################################

echo -e "[  \e[32mOK\e[0m  ]                              Unix time: ${UNIX_TIME}"
echo -e "[  \e[32mOK\e[0m  ]                             Local time: ${LOCAL_TIME}"
echo -e "[  \e[32mOK\e[0m  ]                           Slurm job ID: ${SLURM_JOB_ID}"
echo -e "[  \e[32mOK\e[0m  ]                     Slurm array job ID: ${SLURM_ARRAY_JOB_ID}"
echo -e "[  \e[32mOK\e[0m  ]                    Slurm array task ID: ${SLURM_ARRAY_TASK_ID}"
echo -e "[  \e[32mOK\e[0m  ]                   Slurm job script MD5: ${SLURM_JOB_SCRIPT_MD5}"
echo -e "[  \e[32mOK\e[0m  ]                Slurm job script SHA256: ${SLURM_JOB_SCRIPT_SHA256}"
echo -e "[  \e[32mOK\e[0m  ] Slurm slurm job script number of lines: ${SLURM_JOB_SCRIPT_NUMBER_OF_LINES}"
cat "${SLURM_JOB_SCRIPT}"

#####################################################
############### CONDA INSTALLATION ##################
#####################################################

module purge
module list
cd "${LOCAL_SCRATCH_DIR}"

if [[ -f "${CONDA_ENV_YAML}.md5" ]] && md5sum -c "${CONDA_ENV_YAML}.md5"; then
    
    echo -e "[  \e[32mOK\e[0m  ] Unpacking existing the conda environment to ${LOCAL_SCRATCH_DIR}"
    cp "${CONDA_CACHE_DIR}/${CONDA_ENV_NAME}.tar.gz" ./
    tar -xf "${CONDA_ENV_NAME}.tar.gz"
    
    set +u  # conda crashes without this
    source bin/activate
    conda-unpack
    set -u
    
else
    
    # conda variables
    export CONDA_INSTALL_PATH="${LOCAL_SCRATCH_DIR}/miniconda3"
    export CONDA_ENVS_PATH="${CONDA_INSTALL_PATH}/envs"
    export CONDA_PKGS_DIRS="${CONDA_INSTALL_PATH}/pkgs"
    
    # user already has a miniconda install script
    if [[ -f "${HOME}/Miniconda3-latest-Linux-x86_64.sh" ]]; then
        echo -e "[  \e[32mOK\e[0m  ] Using existing miniconda installer from ${HOME}"
        export CONDA_INSTALLER_SCRIPT="${HOME}/Miniconda3-latest-Linux-x86_64.sh"
        
        # user doesn't have a miniconda install script; install one now
    else
        echo -e "[  \e[32mOK\e[0m  ] Installing miniconda to ${LOCAL_SCRATCH_DIR}"
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
        chmod +x Miniconda3-latest-Linux-x86_64.sh
        export CONDA_INSTALLER_SCRIPT="./Miniconda3-latest-Linux-x86_64.sh"
    fi
    
    "${CONDA_INSTALLER_SCRIPT}" -b -p "${CONDA_INSTALL_PATH}"
    
    # rebuild conda environment from yaml file
    echo -e "[  \e[32mOK\e[0m  ] Re/building the conda environment from ${CONDA_ENV_YAML}"
    source "${CONDA_INSTALL_PATH}/etc/profile.d/conda.sh"
    conda activate base
    conda install -y mamba -n base -c conda-forge
    mamba env create --file "${CONDA_ENV_YAML}"
    conda install -y conda-pack
    
    # pack and cache the env
    echo -e "[  \e[32mOK\e[0m  ] Packing the conda environment and caching it to ${CONDA_CACHE_DIR}"
    conda pack -n "${CONDA_ENV_NAME}" -o "${CONDA_ENV_NAME}.tar.gz"
    cp "${CONDA_ENV_NAME}.tar.gz" "${CONDA_CACHE_DIR}/${CONDA_ENV_NAME}.tar.gz"
    md5sum "${CONDA_ENV_YAML}" > "${CONDA_ENV_YAML}.md5"
    
    set +u  # conda crashes without this
    conda activate "${CONDA_ENV_NAME}" # enter the environment
    set -u
    
fi

echo -e "[  \e[32mOK\e[0m  ] Finalizing the software environment configuration"

#####################################################
############### MLCFLOW INSTALLATION ################
#####################################################

echo -e "[  \e[32mOK\e[0m  ] Setting up MLCFlow"

# install mlcflow and the scripts. these can't be put in the yml since the order of installation matters
# if you put it in the yml, mlc will try to install its own cuda which we dont want
export MLC_REPOS="${LOCAL_SCRATCH_DIR}/MLC/repos"
pip install mlcflow
pip install mlc-scripts
mlc pull repo mlcommons@mlperf-automations --branch=main
mlc run script --tags="get,python,python3,get-python,get-python3,_custom-path.$(which python)"

#####################################################
############### MODEL INSTALLATION ##################
#####################################################

echo -e "[  \e[32mOK\e[0m  ] Downloading BERT model"

# If BERT_MODEL_DIR exists, this will tell MLCFlow to use the model from there.
export BERT_MODEL_DIR="${HOME}/bert_cache/model_fp32"
mlc run script --tags="get,ml-model,bert-large,_onnx" --checkpoint="${BERT_MODEL_DIR}" --outdirname="${LOCAL_SCRATCH_DIR}" -j

#####################################################
############### DATASET INSTALLATION ################
#####################################################

# TODO: dataset caching

echo -e "[  \e[32mOK\e[0m  ] Downloading dataset"

if [ $mode == "a" ]; then
    # get both
    echo -e "[  \e[32mOK\e[0m  ] Downloading validation and calibration dataset"
    mlcr get,dataset,squad,validation  --outdirname="${LOCAL_SCRATCH_DIR}" -j
    mlcr get,dataset,squad,_calib1 --outdirname="${LOCAL_SCRATCH_DIR}" -j
else
    read -p "Download the (v)alidation dataset, (c)alibration dataset, or (b)oth?" input
    
    if [ $input == "v" ]; then
        # validation set
        echo -e "[  \e[32mOK\e[0m  ] Downloading validation dataset"
        mlcr get,dataset,squad,validation  --outdirname="${LOCAL_SCRATCH_DIR}" -j
        
        elif [ $input == "c" ]; then
        # calibration set
        echo -e "[  \e[32mOK\e[0m  ] Downloading calibration dataset"
        mlcr get,dataset,squad,_calib1 --outdirname="${LOCAL_SCRATCH_DIR}" -j
        
        elif [ $input == "b" ]; then
        # get both
        echo -e "[  \e[32mOK\e[0m  ] Downloading validation and calibration dataset"
        mlcr get,dataset,squad,validation  --outdirname="${LOCAL_SCRATCH_DIR}" -j
        mlcr get,dataset,squad,_calib1 --outdirname="${LOCAL_SCRATCH_DIR}" -j
        
    else
        # invalid input. auto install both
        echo -e "[\e[31mFAILED\e[0m] Invalid input. Automatically downloading both"
        echo -e "[  \e[32mOK\e[0m  ] Downloading validation and calibration dataset"
        mlcr get,dataset,squad,validation  --outdirname="${LOCAL_SCRATCH_DIR}" -j
        mlcr get,dataset,squad,_calib1 --outdirname="${LOCAL_SCRATCH_DIR}" -j
    fi
fi

#####################################################
############# RUN INFERENCE BENCHMARK ###############
#####################################################

printenv
echo -e "[  \e[32mOK\e[0m  ] Running the inference benchmark"
# Sourced from https://docs.mlcommons.org/inference/benchmarks/language/bert/#__tabbed_23_1

# Run full version of the benchmark
mlcr run-mlperf,inference,_full,_r5.1-dev \
   --model=bert-99.9 \
   --implementation=reference \
   --framework=pytorch \
   --category=datacenter \
   --scenario=Offline \
   --execution_mode=valid \
   --device=cuda \
   --quiet \
   --skip-install-cuda \
   --offline_target_qps=600

# Run test version of the benchmark
# mlcr run-mlperf,inference,_find-performance,_full,_r5.1-dev \
#    --model=bert-99.9 \
#    --implementation=reference \
#    --framework=pytorch \
#    --category=datacenter \
#    --scenario=Offline \
#    --execution_mode=test \
#    --device=cuda  \
#    --quiet \
#    --test_query_count=500 --rerun \
#    --skip-install-cuda

sleep 6000

#####################################################
############### SAVE RESULTS TO LUSTRE ##############
#####################################################

declare -xr RESULTS_DIR="${LUSTRE_PROJECT_DIR}/results/${SLURM_JOB_NAME}-${SLURM_JOB_ID}-${LOCAL_TIME}"
mkdir -p "${RESULTS_DIR}"

echo -e "[  \e[32mOK\e[0m  ] Copying results to ${RESULTS_DIR}"
cp -r "${LOCAL_SCRATCH_DIR}/." "${RESULTS_DIR}/"

echo -e "[  \e[32mOK\e[0m  ] Results copied successfully"

#####################################################
###################### FINISHED #####################
#####################################################

echo -e "[  \e[32mOK\e[0m  ] Script finished"