#!/bin/bash
#===============================================================================
# run_inversion_distributed.sh
#
# DO NOT run directly — submitted by submit_prospect_inversion.sh via sbatch
# All variables loaded from job_config.sh at runtime
#===============================================================================

## Safety check — refuse to run outside of SLURM
if [ -z "$SLURM_JOB_ID" ]; then
  echo "ERROR: This script must be run via sbatch, not directly."
  echo "  Use: bash submit_prospect_inversion.sh [--test]"
  exit 1
fi

## Load config — all job variables defined here
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: config file not found at $CONFIG_FILE"
  echo "  Run submit_prospect_inversion.sh first to generate it"
  exit 1
fi

source "$CONFIG_FILE"
echo ">>> Config loaded from: $CONFIG_FILE"

## Calculate row range for this task
TASK_ID=${SLURM_ARRAY_TASK_ID}
START_ROW=$(( (TASK_ID - 1) * CHUNK_SIZE + 1 ))
END_ROW=$(( TASK_ID * CHUNK_SIZE ))
JOB_START=$(date +%s)

if [ "$END_ROW" -gt "$TOTAL_ROWS" ]; then
  END_ROW=$TOTAL_ROWS
fi

echo "================================================"
echo " SLURM Job        : $SLURM_JOB_ID"
echo " SLURM Array Task : $TASK_ID"
echo " Row range        : $START_ROW - $END_ROW"
echo " Node             : $(hostname)"
echo " CPUs             : $CPUS"
echo " Memory           : $MEM"
echo " START            : $(date)"
echo "================================================"


cd "$PROJECT_ROOT"
source "${PROJECT_ROOT}/activate-rt_tools_env.sh"

echo " Rscript  : $(which Rscript)"
echo " R version: $(Rscript --version 2>&1)"
echo " RSCRIPT  : $RSCRIPT"
echo " ARGS     : $START_ROW $END_ROW $DATA_DIR $OUTPUT_DIR"
echo "------------------------------------------------"

Rscript "$RSCRIPT" \
  "$START_ROW"  \
  "$END_ROW"    \
  "$DATA_DIR"   \
  "$OUTPUT_DIR"

EXIT_CODE=$?
JOB_END=$(date +%s)
ELAPSED=$(( JOB_END - JOB_START ))
ELAPSED_FMT=$(printf '%02dh:%02dm:%02ds' \
  $(( ELAPSED/3600 )) \
  $(( (ELAPSED%3600)/60 )) \
  $(( ELAPSED%60 )))

echo "================================================"
echo " Task $TASK_ID complete : rows $START_ROW-$END_ROW"
echo " Exit code : $EXIT_CODE"
echo " Elapsed   : $ELAPSED_FMT"
echo " END       : $(date)"
echo "================================================"

exit $EXIT_CODE
#--------------------------------------------------------------------------------------------------#