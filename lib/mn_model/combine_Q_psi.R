#### Follows up on get_Q_psi.R: Completes aggregation of partially aggregated
#### values of q_denominator, psi_denominator & psi_numerator for a subset 
#### of the parts of counts. Code is broken down into two aggregation steps 
#### to speed up the process via parallelization.

#### PRELIMINARIES

# Define iteration range
if (Sys.getenv("TESTING") == TRUE) {
    startIter <- number_Qdenom <- 2 # so as to avoid saving the workspace
} else {
    args          <- commandArgs(TRUE)
    number_Qdenom <- as.integer(args[1])
    startIter     <- 1
}

# Load libs, paths, and settings
source("lib/mn_model/set_env.R")
load(sprintf("%s/settings.rda", results_dir))


#### BEGIN


#### Aggregate values for both true & random series (prefix),  
#### each counts data part, and each nformation criterion.

# For real and random series
for (prefix in prefixes){ 
    cat(paste0("Prefix: ", prefix, "\n"))   

    # For each information criterion
    for(ic in IC){   
        cat(paste0("    IC: ", ic, "\n"))

        prefix_ic <- sprintf("%s%s", prefix, ic)
    
        q_denom <- psi_denom <- psi_numer <- 0
    
        # For each partial sum from get_Q_psi.R
        for (i in startIter:number_Qdenom){

            q_denom   <- q_denom   + readRDS(sprintf("%s/%s-q_denom%02d.rds",   scratch_dir, prefix_ic, i))
            psi_numer <- psi_numer + readRDS(sprintf("%s/%s-psi_numer%02d.rds", scratch_dir, prefix_ic, i))
            psi_denom <- psi_denom + readRDS(sprintf("%s/%s-psi_denom%02d.rds", scratch_dir, prefix_ic, i))
            
        }
    
        psi <- psi_numer / psi_denom
        saveRDS(q_denom, file = sprintf("%s/%s-q_denom.rds", results_dir, prefix_ic), compress = FALSE)
        saveRDS(psi,     file = sprintf("%s/%s-psi.rds",     results_dir, prefix_ic), compress = FALSE)
    
    }
}

