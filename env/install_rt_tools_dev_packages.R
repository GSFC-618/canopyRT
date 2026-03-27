#!/usr/bin/env Rscript

cat("Checking what's already installed via conda...\n")
installed <- rownames(installed.packages())
cat("Found", length(installed), "packages already installed\n")

# Install from CRAN (pixi search <r-bayesiantools> to see if avail in pixi/conda)
cran_packages <- c("BayesianTools") 
missing_cran <- cran_packages[!cran_packages %in% installed]
if(length(missing_cran) > 0) {
    cat("Installing from CRAN:", paste(missing_cran, collapse=", "), "\n")
    install.packages(missing_cran, repos = "https://cran.rstudio.com/")
}

# Install from GitHub
cat("Installing rrtm from GitHub...\n")
devtools::install_github("ashiklom/rrtm")

cat("All packages installed successfully!\n")