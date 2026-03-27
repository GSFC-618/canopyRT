# RT Tools R Environment

Shared R environment with development tools for radiative transfer dev

## Quick Start

### Activate Environment
```bash
# Navigate to tools directory
cd /shared/users/radiative_transfer/canopyRT

# Activate environment - this may require pixi install if not installed/available
source activate-rt_tools_env.sh

# Start R with all tools available
R

# ---
## Example for batch slurm script usage (NEED TO TEST) - this will be slow potentially 
# see for info on pcluster: https://airborne-smce.readthedocs.io/en/latest/pages/pcluster.html

#!/bin/bash
#SBATCH --partition=demand-8cpu

# Activate RT Tools environment
source /shared/users/radiative_transfer/canopyRT/activate-rt_tools_env.sh

# Run R analysis
Rscript <script_name>.R


# ---
## For Package Development (Advanced)
If you need to install additional R packages from source:

```bash
# One-time setup for compilation
pixi run setup-makevars

# Then you can install from source/GitHub
R -e "install.packages('newpackage', type='source')"
R -e "devtools::install_github('user/repo')"