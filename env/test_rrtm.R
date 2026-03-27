#!/usr/bin/env Rscript

cat("Testing rrtm installation...\n")

# Test loading rrtm
tryCatch({
    library(rrtm)
    cat("rrtm loaded successfully!\n")
    
    # Basic test - expand to other use cases
    cat("Package test completed successfully!\n")
    
}, error = function(e) {
    cat("Error loading rrtm:", conditionMessage(e), "\n")
    quit(status = 1)
})

# Test other packages if needed
required_packages <- c("here", "dplyr", "coda", "distributions3", "BayesianTools")
for(pkg in required_packages) {
    tryCatch({
        library(pkg, character.only = TRUE)
        cat(pkg, "loaded successfully!\n")
    }, error = function(e) {
        cat("Error loading", pkg, ":", conditionMessage(e), "\n")
    })
}

cat("All tests completed!\n")