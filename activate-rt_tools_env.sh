#!/bin/bash
# Activation script for RT Tools R Environment

echo "Usage 'source activate-rt_tools_env.sh' not 'bash activate-rt_tools_env.sh'"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RT_TOOLS_ENV="${SCRIPT_DIR}/env"
echo $RT_TOOLS_ENV

SHARED_PREFIX="/shared"
PIXI_BIN="/home/$(id -un)/.pixi/bin/pixi"
# which pixi
unset PIXI_DETACHED_ENVIRONMENTS
export PIXI_DETACHED_ENVIRONMENTS="${SHARED_PREFIX}/users-local/radiative_transfer/canopyRT/env/pcluster"

if [ ! -d "$RT_TOOLS_ENV" ]; then
    echo "Error: RT Tools environment docs not found at $RT_TOOLS_ENV"
    return 1
fi

if [ ! -x "$PIXI_BIN" ]; then
  echo "ERROR: pixi not found at $PIXI_BIN"
  echo "  Install: curl -fsSL https://pixi.sh/install.sh | sh"; return 1
fi

command -v conda &>/dev/null && [ -n "$CONDA_DEFAULT_ENV" ] && conda deactivate

# Activate the environment
echo "Activating RT Tools R Environment..."
cd "$RT_TOOLS_ENV"
eval "$("$PIXI_BIN" shell-hook)"
cd "$SCRIPT_DIR"

echo "  R version: $(R --version | head -1)"
echo "  env       : $PIXI_DETACHED_ENVIRONMENTS"