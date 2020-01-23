#### Aggregates values of q_denominator, psi_denominator & psi_numerator
#### for a subset of the parts of counts. This code is followed by combine_Q_psi.R.
#### Code is broken down into two aggregation steps to speed up the process via
#### parallelization.
#### Don't use fuctions, avoid copying large objects in memory.


#### Set up environment

# Define parts of counts files to operate
if (Sys.getenv("TESTING") == TRUE) {
    parts <- parts_range <- 2 # so as to avoid saving the workspace
} else {
    args        <- commandArgs(TRUE)
    parts_range <- as.integer(Sys.getenv('SLURM_ARRAY_TASK_ID'))
    parts_step  <- as.integer(args[1])
    parts       <- 1:256
    parts       <- parts[((parts_range - 1) * parts_step + 1):(parts_range * parts_step)]
}

# Load libs, paths, and settings
source("lib/mn_model/set_env.R")
source("lib/mn_model/utility_functions.R")
load(sprintf("%s/settings.rda", results_dir))
if(length(scratch_fit)!=0){
    scratch_fit_dir <- sprintf("%s/%s", scratch, scratch_fit)
    exclude         <- TRUE
} else {
    scratch_fit_dir <- scratch_dir
    exclude         <- FALSE
}


#### BEGIN 

#### Aggregate values for both true & random series (prefix),  
#### each counts data part, and each information criterion.
#### Phrase-level computations are performed simultaneously using matrices

# For real/random
for (prefix in prefixes){
    cat(paste0("Prefix: ", prefix, "\n"))

    # Load variables used in MN model estimation
    load(sprintf("%s/variables.rda", results_dir))
    if (prefix == "rand_") varInt  <- varIntfake 

    pre_fit_objects <- get_pre_fit_objects(varInt, U)
    party <- pre_fit_objects[['party']]
    newU <- pre_fit_objects[['newU']]
    rm(pre_fit_objects)
    gc()


    # Prepare variables to store parameter values
    q_denom        <- psi_denom        <- psi_numer        <- rep(list(0), length(IC))
    names(q_denom) <- names(psi_denom) <- names(psi_numer) <- IC

    # For each part of estimation
    for (part in parts){

        fit     <- readRDS(sprintf("%s/%s-fit%03d.rds", scratch_fit_dir, prefix, part))
        if(length(bic_scratch_fit) != 0){
            bic_fit_dir <- sprintf("%s/%s", scratch, bic_scratch_fit)
            bic_fit     <- readRDS(sprintf("%s/%s-fit%03d.rds", bic_fit_dir, prefix, part))
        }
        # For each information criterion
        for(ic in IC) {
            cat(paste0("    IC: ", ic, "\n"))
            # Rule for lambda-selection via CV, leave null for analytic criteria
            if ((ic == "1se") | (ic == "min")){
                sel <- ic
            } else {
                sel <- NULL
            }

            # Extract all coefficient estimates for utility of each phrase
            beta         <- coef(fit, select = sel, k = k[ic],    corrected = FALSE)
            if (length(bic_scratch_fit) != 0){
                bic_beta <- coef(bic_fit, select = sel, k = bic_k, corrected = FALSE)
            } else {
                bic_beta = NULL
            }
            # Calculate utility
            utility_list <- calculate_utility(beta, varInt, party, newU, bic_beta, exclude)
            utility_dem  <- utility_list[['utility_dem']]
            utility_rep  <- utility_list[['utility_rep']]
            utility      <- utility_list[['utility']]
            rm(utility_list)
            gc()
            
            # Accumulate sums 
            psi_denom[[ic]] <- rowSums(exp(utility_rep)) + psi_denom[[ic]]
            psi_numer[[ic]] <- rowSums(exp(utility_dem)) + psi_numer[[ic]]
            q_denom[[ic]]   <- rowSums(exp(utility))     + q_denom[[ic]]
        }
    }

    # For each information criterion
    for (ic in IC){
        prefix_ic <- sprintf("%s%s", prefix, ic)

        # Store outputs
        saveRDS(q_denom[[ic]],   file = sprintf("%s/%s-q_denom%02d.rds",   scratch_dir, prefix_ic, parts_range), compress = FALSE)
        saveRDS(psi_denom[[ic]], file = sprintf("%s/%s-psi_denom%02d.rds", scratch_dir, prefix_ic, parts_range), compress = FALSE)
        saveRDS(psi_numer[[ic]], file = sprintf("%s/%s-psi_numer%02d.rds", scratch_dir, prefix_ic, parts_range), compress = FALSE)
    }
}


