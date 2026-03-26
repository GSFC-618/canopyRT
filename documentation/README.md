# Install dependencies for rrtm and forward/inversion codes
NOTE: These instructions need additional testing and vetting by others

### Mac OSX
To install on a Mac computer, you will need to have Xcode, Xcode command line utilities, and typically an ~/.R/Makevars (see example below) to point R to compilers that have support for the libraries needed for rrtm.

Below are example steps that may require modification for specific local installations:

1) Install homebrew <br>
   `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

2) Install llvm (recommended) <br>
   `brew install llvm`
   
3) Install gcc <br>
   `brew install gcc`
   
4) Create your local `~/.R/Makevars/`
   ```bash
   cd ~
   mkdir .R
   cd .R
   touch Makevars
   vim Makevars
   ```

5) Populate your `~/.R/Makevars/`, for example if using gcc15 and llvm22
   ```bash
   VER=15
   FC=gfortran-$(VER)
   CC = /opt/homebrew/Cellar/llvm/22.1.1/bin/clang
   CXX = /opt/homebrew/Cellar/llvm/22.1.1/bin/clang++ -fopenmp -std=gnu++11
   CXX98 = /opt/homebrew/Cellar/llvm/22.1.1/bin/clang++ -fopenmp
   CXX11 = /opt/homebrew/Cellar/llvm/22.1.1/bin/clang++ -fopenmp
   CXX14 = /opt/homebrew/Cellar/llvm/22.1.1/bin/clang++ -fopenmp
   CXX17 = /opt/homebrew/Cellar/llvm/22.1.1/bin/clang++ -fopenmpi

   FLIBS=-L/opt/homebrew/Cellar/gcc/15.2.0_1/lib/gcc/$(VER) -lgfortran -lquadmath -lm
   ```
6) Restart your R or Rstudio session and install the libraries
   ```r
  devtools::install_github("ashiklom/rrtm")
  install.packages(c("here", "dplyr", "coda", "distributions3", "BayesianTools"))
   ```
7) Test load rrtm to confirm its installed correctly

8) Run  a test script

### Linux x64 - Airborne SMCE pcluster


