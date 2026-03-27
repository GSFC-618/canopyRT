#!/bin/bash
# Activation script for RT Tools R Environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RT_TOOLS_ENV="${SCRIPT_DIR}/env"

if [ ! -d "$RT_TOOLS_ENV" ]; then
    echo "Error: RT Tools environment not found at $RT_TOOLS_ENV"
    exit 1
fi

cd "$RT_TOOLS_ENV"

# Check if pixi is available
# install: curl -fsSL https://pixi.sh/install.sh | sh
if ! command -v pixi &> /dev/null; then
    echo "Error: pixi not found. Please install pixi first."
    echo "Example install: curl -fsSL https://pixi.sh/install.sh | sh"
    exit 1
fi

# Activate the environment
echo "Activating RT Tools R Environment..."
eval "$(pixi shell-hook)"

echo "  RT Tools R Environment activated!"
echo "  R version: $(R --version | head -1)"
echo "  Environment location: $RT_TOOLS_ENV"
echo "  Use 'exit' to deactivate"