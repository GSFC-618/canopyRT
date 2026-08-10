#!/bin/bash
#SBATCH --job-name=test
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:30:00
#SBATCH --partition=demand-16cpu
#SBATCH --output=logs/prospect_%A.out
#SBATCH --error=logs/prospect_%A.err

PROJECT_ROOT="/shared/users-local/radiative_transfer/canopyRT/"
DATA_DIR="${PROJECT_ROOT}/data/compiled_data/"
OUTPUT_DIR="${PROJECT_ROOT}/temp/"

cd $PROJECT_ROOT
source activate-rt_tools_env.sh

cd $PROJECT_ROOT
source activate-rt_tools_env.sh
n1=100
n2=103

Rscript pcluster/invert_leaf_refl_spectra_PROSPECT-pcluster.R $n1 $n2 $DATA_DIR $OUTPUT_DIR # "NGEETropics_Leaf_Reflectance.RData" "Panama2016"

exit 0
