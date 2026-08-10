#!/bin/bash

# Get pixi environment path
PIXI_ENV_PATH="$(pwd)/.pixi/envs/default"

echo "Using pixi environment path: $PIXI_ENV_PATH"

# Create .R directory in user home (or in shared space)
mkdir -p ~/.R

# Create Makevars for Linux compilation
cat > ~/.R/Makevars << EOF
# Compiler settings for pixi environment
CC = ${PIXI_ENV_PATH}/bin/x86_64-conda-linux-gnu-gcc
CXX = ${PIXI_ENV_PATH}/bin/x86_64-conda-linux-gnu-g++
CXX98 = ${PIXI_ENV_PATH}/bin/x86_64-conda-linux-gnu-g++
CXX11 = ${PIXI_ENV_PATH}/bin/x86_64-conda-linux-gnu-g++ -std=gnu++11 
CXX14 = ${PIXI_ENV_PATH}/bin/x86_64-conda-linux-gnu-g++ -std=gnu++14
CXX17 = ${PIXI_ENV_PATH}/bin/x86_64-conda-linux-gnu-g++ -std=gnu++17
FC = ${PIXI_ENV_PATH}/bin/x86_64-conda-linux-gnu-gfortran

# Standards
CXX11STD = -std=gnu++14
CXX14STD = -std=gnu++14                                     
CXX17STD = -std=gnu++17

# Default C++ standard 
CXXFLAGS = -std=gnu++14 -fPIC -g -O2    

# Library paths
FLIBS = -L${PIXI_ENV_PATH}/lib -lgfortran -lquadmath -lm
LDFLAGS = -L${PIXI_ENV_PATH}/lib
CPPFLAGS = -I${PIXI_ENV_PATH}/include

# PKG_CONFIG settings
PKG_CONFIG_PATH = ${PIXI_ENV_PATH}/lib/pkgconfig:${PIXI_ENV_PATH}/share/pkgconfig
EOF

echo "Makevars created at ~/.R/Makevars"
echo "Contents:"
cat ~/.R/Makevars