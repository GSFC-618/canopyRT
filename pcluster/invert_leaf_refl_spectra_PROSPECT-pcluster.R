####################################################################################################
#
#   Invert leaf reflectance data to estimate transmittance and calculate leaf absorption
#   -- SLURM Worker Script (chunked row range version)
#   -- Post-loop processing moved to: post_process_prospect_inversion.R
#
#   Usage (via SLURM):
#     Rscript run_prospect_inversion_worker.R <start_row> <end_row>
#     e.g.: Rscript run_prospect_inversion_worker.R 1 100
#
#   Outputs (per chunk, written to out.dir):
#     chunk_<start_row>_<end_row>_output_LRT.rds
#     chunk_<start_row>_<end_row>_mod_params.rds
#     chunk_<start_row>_<end_row>_p_refl_stats.rds
#     chunk_<start_row>_<end_row>_meta.rds        # row indices + sample info for reassembly
#
#   Author: Shawn P. Serbin
#   Refactored for SLURM/pcluster by: Colin Quinn
#   Last updated: 2026-04-15
#
#   Project: PACE functional traits
####################################################################################################


#--------------------------------------------------------------------------------------------------#
# Parse command-line arguments from SLURM batch script
# Expected: Rscript run_prospect_inversion_worker.R <start_row> <end_row>
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 4) {
  stop(paste(
    "ERROR: Four arguments required.",
    "Usage: Rscript run_prospect_inversion_worker.R <start_row> <end_row> <data_dir> <output_dir>",
    "  start_row  : first row of chunk (integer)",
    "  end_row    : last row of chunk (integer)",
    "  data_dir   : path to input data directory",
    "  output_dir : path to output directory",
    #"  compiled_dataset: compiled spectral reflectance RData",
    #"  dataID     : dataID string in compiled_dataset",
    sep = "\n"
  ))
}

start_row  <- as.integer(args[1])
end_row    <- as.integer(args[2])
data_dir   <- args[3]
output_dir <- args[4]
# compiled_dataset <- args[5] # e.g., NGEETropics_Leaf_Reflectance.RData
# data_id <- args[6] #e.g., Panama2016

if (is.na(start_row) || is.na(end_row)) {
  stop("ERROR: start_row and end_row must be valid integers.")
}
if (start_row < 1) {
  stop("ERROR: start_row must be >= 1.")
}
if (end_row < start_row) {
  stop("ERROR: end_row must be >= start_row.")
}
if (!dir.exists(data_dir)) {
  stop(sprintf("ERROR: data_dir not found: %s", data_dir))
}

# Create output_dir if it doesn't exist
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
  cat(sprintf(">>> Created output_dir: %s\n", output_dir))
}

cat(sprintf(">>> Worker started : rows %d to %d\n", start_row, end_row))
cat(sprintf(">>> data_dir       : %s\n", data_dir))
cat(sprintf(">>> output_dir     : %s\n", output_dir))

#--------------------------------------------------------------------------------------------------#

# Clear workspace
rm(list = setdiff(ls(), c("start_row", "end_row", "data_dir", "output_dir", "args"))) 
graphics.off()
closeAllConnections()

# Load libraries
ok <- require(rrtm)
if (!ok) {
  devtools::install_github("ashiklom/rrtm")
} else {
  print("*** Package found: rrtm ***")
}

list.of.packages <- c("here", "dplyr", "coda", "distributions3",
                      "BayesianTools", "rrtm")
invisible(lapply(list.of.packages, library, character.only = TRUE))

`%notin%` <- Negate(`%in%`)

custom_prior <- TRUE

# Burnin helper (PEcAn-sourced)
source(file.path(here::here(), "Rscripts", "functions", "autoburnin.R"))

# User options
output_licor <- FALSE

# Load data
load(file.path(data_dir, "NGEETropics_Leaf_Reflectance.RData"))
#--------------------------------------------------------------------------------------------------#
# Import leaf spectra and metadata
dataID  <- "Panama2016"
dataset <- NGEETropics_leaf_reflectance[[paste0(dataID, "_leaf_refl")]]

# ---- Validate row range against actual data size ----
total_rows <- nrow(dataset)
if (start_row > total_rows) {
  stop(sprintf(
    "ERROR: start_row (%d) exceeds total rows in dataset (%d).",
    start_row, total_rows
  ))
}
if (end_row > total_rows) {
  warning(sprintf(
    "WARNING: end_row (%d) exceeds total rows (%d). Clamping to %d.",
    end_row, total_rows, total_rows
  ))
  end_row <- total_rows
}

row_indices <- start_row:end_row   # absolute row indices into full dataset
chunk_label <- sprintf("%04d_%04d", start_row, end_row)

cat(sprintf(">>> Processing %d spectra (rows %d-%d of %d total)\n",
            length(row_indices), start_row, end_row, total_rows))
#--------------------------------------------------------------------------------------------------#


#--------------------------------------------------------------------------------------------------#
# Spectral setup and full-dataset sample info (needed for output metadata)
Start.wave    <- 350
End.wave      <- 2500
spec_waves    <- names(dataset)[match(paste0("Wave_", seq(Start.wave, End.wave, 1)), names(dataset))]
refl_samp_info <- dataset[, "Sample_ID"]
spectra        <- droplevels(dataset[, spec_waves])

output_sample_info_all <- data.frame(
    Spectra_Name    = refl_samp_info,
    Location        = dataset[, "Site"],
    Instrument      = dataset[, "Instrument"],
    Species_Code    = dataset[, "Species_Code"],
    Genus           = dataset[, "Genus"],
    Species         = dataset[, "Species"],
    Canopy_position = dataset[, "Canopy_position"],
    PLSR_LeafAge_days = dataset[, "PLSR_LeafAge_days"],
    Measurement_Date  = dataset[, "Sample_Date"]
)
head(output_sample_info_all)

names_output_sample_info <- names(output_sample_info_all)

# ---- Subset to this chunk's rows ----
output_sample_info_all <- output_sample_info_all[row_indices, , drop = FALSE]
spectra                <- spectra[row_indices, , drop = FALSE]
refl_samp_info         <- refl_samp_info[row_indices]

#--------------------------------------------------------------------------------------------------#
# Subset spectra to inversion wavelength range
Start.wave.inv  <- 470    # 470 480; to avoid the "ski jump" < 450 nm with some spectra
End.wave.inv    <- 2500
subset_waves    <- seq(Start.wave.inv, End.wave.inv, 1)

abs.Start.wave <- 400  # start abs calc wavelength
abs.End.wave <- 700    # end abs calc wavelength

sub_refl_data <- spectra[, which(names(spectra) %in% paste0("Wave_", seq(Start.wave.inv, End.wave.inv, 1)))]
sub_refl_data <- sub_refl_data * 0.01   # scale to 0-1 before proceeding

waves <- seq(Start.wave.inv, End.wave.inv, 1)
prospect_waves <- seq(400, 2500, 1)

chunk_nrows <- nrow(sub_refl_data)
cat(sprintf(">>> Chunk size: %d rows\n", chunk_nrows))

#--------------------------------------------------------------------------------------------------#
# Output directory (shared top-level; chunk files are distinguished by label in filename)
out.dir <- file.path(output_dir, "R_Output", dataID,
                     "PROSPECTD_rrtm-TEST", "Range_400_700nm")
if (!file.exists(out.dir)) dir.create(out.dir, recursive = TRUE)

# Chunk-specific subdir for per-sample MCMC trace PDFs
chunk.out.dir <- file.path(out.dir, paste0("chunk_", chunk_label))
if (!file.exists(chunk.out.dir)) dir.create(chunk.out.dir, recursive = TRUE)

chunk_file <- function(obj_name) {
  file.path(out.dir, sprintf("chunk_%s_%s.rds", chunk_label, obj_name))
}

#--------------------------------------------------------------------------------------------------#


#--------------------------------------------------------------------------------------------------#
## Run inversions - whole directory — sized to THIS CHUNK only
output.LRT <- list(
    Spec.Info        = array(NA, dim = c(chunk_nrows, ncol(output_sample_info_all))),
    obs.Reflectance  = array(NA, dim = c(chunk_nrows, length(waves))),
    mod.Reflectance  = array(NA, dim = c(chunk_nrows, length(prospect_waves))),
    mod.Transmittance = array(NA, dim = c(chunk_nrows, length(prospect_waves)))
)

mod.params <- array(NA, dim = c(chunk_nrows, 21))
# Name mod.params columns
mod.params <- as.data.frame(mod.params)
names(mod.params) <- c(
  "N.mu",      "N.q25",      "N.q975",
  "Cab.mu",    "Cab.q25",    "Cab.q975",
  "Car.mu",    "Car.q25",    "Car.q975",
  "Cbrown.mu", "Cbrown.q25", "Cbrown.q975",
  "Canth.mu",  "Canth.q25",  "Canth.q975",
  "Cw.mu",     "Cw.q25",     "Cw.q975",
  "Cm.mu",     "Cm.q25",     "Cm.q975"
)
# inv.samples <- NA
# names: N.mu, N.q25, N.q975, Cab.mu, Cab.q25, Cab.q75, Car.mu, Car.q25, Car.q75, 
# Cbrown.mu, Cbrown.q25, Cbrown.q75, Canth.mu, Canth.q25, Canth.q75,
# Cw.mu, Cw.q25, Cw.q75, Cm.mu, Cm.q25, Cm.q75, gelman.diag
#--------------------------------------------------------------------------------------------------#


#--------------------------------------------------------------------------------------------------#
### Run inversion: PROSPECT-D w/ rrtm

# setup prospect error envelope list
p.refl.stats <- list(lower = array(data = NA, c(chunk_nrows, 2101)),
                     upper = array(data = NA, c(chunk_nrows, 2101)))


# setup likelihood function
likelihood <- function(params) {
    # N, Cab, Car, Cbrown, Canth, Cw, Cm,
    mod <- prospectd(params[1], params[2], params[3], params[4], params[5],
                     params[6], params[7])$reflectance[min(which(prospect_waves %in% subset_waves, arr.ind = TRUE)):2101]
    sum(dnorm(obs, mod, params[8], log = TRUE))
}
# !! in here the likelihood assumes the spectra to invert is labeled "obs"

## --------------------- Define priors --------------------- ##
# Define prior distribution objects here
# N density
Nd <- distributions3::Normal(1, 6)

# Cab density
#Cabd <- distributions3::Normal(40, 15)
#Cabd <- distributions3::LogNormal(4.1, 0.35)
Cabd <- distributions3::Normal(65, 22)

# Car density
#Card <- distributions3::LogNormal(2.1, 0.2)
Card <- distributions3::Gamma(2.1, 0.2)
#curve(dlnorm(x, 2.1, 0.7), 0, 40)

# Cbrown density
Cbrownd <- distributions3::Normal(0.05, 0.03)

# Cant density
#Canthd <- distributions3::LogNormal(2.1, 0.2)
#curve(dlnorm(x, 2.1, 0.7), 0, 40)
Canthd <- distributions3::Gamma(1.1, 0.08)

# Cw density  
#Cwd <- distributions3::LogNormal(-4.456, 1.216)
#curve(dlnorm(x, -4.456, 1.216), 0, 0.2)
Cwd <- distributions3::LogNormal(-4.456, 1.3)

# Cm density
Cmd <- distributions3::LogNormal(-5.15, 1.328)

# resid density
rsdd <- distributions3::Exponential(10)
## --------------------- END Define priors --------------------- ##


## --------------------- Create priors --------------------- ##

prior <- createPrior(
    density = function(x) {
        distributions3::log_pdf(Nd,      x[1]) +
        distributions3::log_pdf(Cabd,    x[2]) +
        distributions3::log_pdf(Card,    x[3]) +
        distributions3::log_pdf(Cbrownd, x[4]) +
        distributions3::log_pdf(Canthd,  x[5]) +
        distributions3::log_pdf(Cwd,     x[6]) +
        distributions3::log_pdf(Cmd,     x[7]) +
        distributions3::log_pdf(rsdd,    x[8])
    },
    sampler = function(n = 1) {
        cbind(
            N      = distributions3::random(Nd,      n),
            Cab    = distributions3::random(Cabd,    n),
            Car    = distributions3::random(Card,    n),
            Cbrown = distributions3::random(Cbrownd, n),
            Canth  = distributions3::random(Canthd,  n),
            Cw     = distributions3::random(Cwd,     n),
            Cm     = distributions3::random(Cmd,     n),
            rsd    = distributions3::random(rsdd,    n)
        )
    },
    lower = c(1,   1,  0, 0,  0, 0, 0, 0),
    upper = c(7, 195, 30, 1, 15, 1, 1, 1) # are these OK upper constraints?
)
## --------------------- END Create priors --------------------- ##

# setup the inversion
setup <- createBayesianSetup(
  likelihood = likelihood,
  prior = prior
)

# Plot title variable
title_var <- "Spectra_Name"


# Inversion loop — iterates over LOCAL (chunk) indices 1:chunk_nrows
# i       = local chunk index  (1 .. chunk_nrows)
# abs_i   = absolute dataset row (start_row .. end_row)  — used for labeling only
print("Starting Inversion:")
cat(sprintf("Inverting %d spectra (chunk rows %d-%d)\n",
            chunk_nrows, start_row, end_row))

pb <- txtProgressBar(min = 0, max = chunk_nrows, width = 50, style = 3)

system.time(
    for (i in seq_len(chunk_nrows)) {
        
        abs_i <- row_indices[i]   # absolute row index for traceability

        tryCatch({
            cat(sprintf("\n>>> [chunk row %d / %d | abs row %d] Inverting: %s\n",
                        i, chunk_nrows, abs_i,
                        unlist(output_sample_info_all[i, title_var])))
    
            # ---- Run MCMC ----
            obs <- unlist(sub_refl_data[i, ])
            settings <- list(iterations = 75000)
            samples <- BayesianTools::runMCMC(setup, sampler = "DEzs", settings = settings)    
            samples_burned <- autoburnin(BayesianTools::getSample(samples, coda = TRUE),method = "gelman.plot")
            coda::varnames(samples_burned) <- c("N", "Cab", "Car", "Cbrown", "Canth", "Cw", "Cm", "rsd")    
            mean_estimates <- do.call(cbind, summary(samples_burned)[c("statistics", "quantiles")])
            row.names(mean_estimates) <- c("N", "Cab", "Car", "Cbrown", "Canth", "Cw", "Cm", "rsd")
        
            # ---- MCMC trace PDF (written to chunk-specific subdir) ----
            pdf_name <- paste0(unlist(output_sample_info_all[i, title_var]),"_abs", abs_i, "_MCMC_trace_diag.pdf")
            grDevices::pdf(file = file.path(chunk.out.dir, pdf_name), 
                           width = 8, height = 6, onefile = TRUE)        
            par(mfrow = c(1, 1), mar = c(2, 2, 2, 2), oma = c(0.1, 0.1, 0.1, 0.1)) # B, L, T, R
            plot(samples_burned)
            dev.off()
    
            # ---- Error Envelope ----
            # include process error in error envelop (i.e. generate prediction interval)
            #n_target <- 1000
            spec.length  <- 2101
            param.samples <- do.call(rbind, samples_burned)
            n_target      <- if (nrow(param.samples) < 1000) nrow(param.samples) else 1000
            param.samples <- param.samples[sample(nrow(param.samples), n_target), ]
            RT_pred       <- array(data = NA, c(n_target, 2101))
        
            cat("*** Calculating error stats ***\n")
            for (r in seq_len(n_target)) {
              RT_pred[r, ] <- rnorm(spec.length, rrtm::prospectd(param.samples[r, 1], param.samples[r, 2],
                                                                 param.samples[r, 3], param.samples[r, 4],
                                                                 param.samples[r, 5], param.samples[r, 6],
                                                                 param.samples[r, 7])$reflectance,
                                    param.samples[r, 8])
            }
    
            # stats
            p.refl.stats$lower[i, ] <- apply(RT_pred, 2, stats::quantile, probs = 0.05, na.rm = TRUE)
            p.refl.stats$upper[i, ] <- apply(RT_pred, 2, stats::quantile, probs = 0.95, na.rm = TRUE)
        
            # Generate modelled spectra 
            num_params   <- 7 # PROSPECT-D
            input.params <- as.vector(unlist(mean_estimates[, 1]))[1:num_params]
            LRT          <- prospectd(input.params[1], input.params[2], input.params[3], input.params[4], 
                                      input.params[5], input.params[6], input.params[7])    
            output_sample_info <- droplevels(output_sample_info_all[i, , drop = FALSE])
        
            output.LRT$Spec.Info[i, ]         <- unlist(lapply(output_sample_info, as.character))
            output.LRT$obs.Reflectance[i, ]   <- as.vector(unlist(sub_refl_data[i, ]))
            output.LRT$mod.Reflectance[i, ]   <- LRT$reflectance
            output.LRT$mod.Transmittance[i, ] <- LRT$transmittance
        
            # ---- Extract parameter summary ----
            get_est <- function(param, stat) {
                mean_estimates[row.names(mean_estimates) == param,
                               colnames(mean_estimates)  == stat]
            }
            mod.params[i, ] <- c(
                get_est("N",      "Mean"), get_est("N",      "25%"),  get_est("N",      "97.5%"),
                get_est("Cab",    "Mean"), get_est("Cab",    "25%"),  get_est("Cab",    "97.5%"),
                get_est("Car",    "Mean"), get_est("Car",    "25%"),  get_est("Car",    "97.5%"),
                get_est("Cbrown", "Mean"), get_est("Cbrown", "25%"),  get_est("Cbrown", "97.5%"),
                get_est("Canth",  "Mean"), get_est("Canth",  "25%"),  get_est("Canth",  "97.5%"),
                get_est("Cw",     "Mean"), get_est("Cw",     "25%"),  get_est("Cw",     "97.5%"),
                get_est("Cm",     "Mean"), get_est("Cm",     "25%"),  get_est("Cm",     "97.5%")
            )
        
  
            rm(samples, samples_burned, input.params, LRT, mean_estimates,
               param.samples, RT_pred, output_sample_info)
    
            cat("\n>>> Done with row", abs_i, "— starting next inversion\n\n")
    
            flush.console()

            saveRDS(output.LRT,   chunk_file("output_LRT"))
            saveRDS(mod.params,   chunk_file("mod_params"))
            saveRDS(p.refl.stats, chunk_file("p_refl_stats"))    
            cat(sprintf(">>> Checkpoint saved after abs row %d\n", abs_i))

        }, error = function(e) {
            cat(sprintf("\n---ERROR on abs row %d: %s — skipping.---\n", abs_i, conditionMessage(e)))
        })
        setTxtProgressBar(pb, i)  
    }  ## End inversion loop
)
close(pb)

#--------------------------------------------------------------------------------------------------#
# Save chunk outputs as RDS for post-processing reassembly
# Naming convention:  chunk_<XXXX>_<YYYY>_<object>.rds
# Metadata for reassembly: absolute row indices + sample info column names
chunk_meta <- list(
  start_row              = start_row,
  end_row                = end_row,
  row_indices            = row_indices,      # absolute indices into full dataset
  names_output_sample_info = names_output_sample_info,
  dataID                 = dataID,
  subset_waves           = subset_waves,
  prospect_waves         = prospect_waves,
  waves                  = waves,
  abs.Start.wave         = abs.Start.wave,
  abs.End.wave           = abs.End.wave
)

saveRDS(output.LRT,    chunk_file("output_LRT"))
saveRDS(mod.params,    chunk_file("mod_params"))
saveRDS(p.refl.stats,  chunk_file("p_refl_stats"))
saveRDS(chunk_meta,    chunk_file("meta"))

cat(sprintf("\n>>> Chunk %s complete. RDS files written to:\n    %s\n",
            chunk_label, out.dir))
cat(sprintf("    chunk_%s_output_LRT.rds\n",   chunk_label))
cat(sprintf("    chunk_%s_mod_params.rds\n",   chunk_label))
cat(sprintf("    chunk_%s_p_refl_stats.rds\n", chunk_label))
cat(sprintf("    chunk_%s_meta.rds\n",         chunk_label))
#--------------------------------------------------------------------------------------------------#

### EOF — post-loop processing in post_process_prospect_inversion.R
