#### Combines polarization measures computed in Fit2Polar.R


## Preliminaries
source("lib/mn_model/set_env.R")
load(sprintf("%s/settings.rda", results_dir))



## Combining polar_measures for each fit
# For each prefix
for (prefix in prefixes) {
    cat(paste0("Prefix: ", prefix, "\n"))  

    # For each information criterion
    for (ic in IC) {
        cat(paste0("    IC: ", ic, "\n"))
        prefix_ic <- sprintf("%s%s", prefix, ic)

        # For each polarization measure
        for (i in measures){
            cat(paste0("        Measure: ", i, "\n"))
            
            polar_measures[[i]] <- 0

            for (l in Sys.glob(sprintf("%s/%s-%s*.rds", scratch_dir, prefix_ic, i)))
                polar_measures[[i]] <- polar_measures[[i]] + readRDS(l)
            
            write.table(
                cbind(speakerindex = rownames(polar_measures[[i]]), polar_measures[[i]]), 
                file = sprintf("%s/%s-%s.txt", results_dir, prefix_ic, i),
                row.names = FALSE,  sep = "|", quote = FALSE)
        }

        ## Combine betas, covariates, and lambdas
        BETA <- NULL
        for (c in Sys.glob(sprintf("%s/%s-b*.rds", scratch_dir, prefix_ic))){
            if (length(BETA) == 0) {
                BETA <- readRDS(c)
            } else {
                BETA <- rBind(BETA, readRDS(c))
            }
        }
        saveRDS(BETA, sprintf("%s/%s-beta.rds", results_dir, prefix_ic))
        BETA <- NULL
        
        COVARS <- NULL
        for (c in Sys.glob(sprintf("%s/%s-covar_coefs*.rds", scratch_dir, prefix_ic))){
            if (length(COVARS) == 0) {
                COVARS <- readRDS(c)
            } else {
                COVARS <- cBind(COVARS, readRDS(c))
            }
        }
        saveRDS(COVARS, sprintf("%s/%s-covar_coefs.rds", results_dir, prefix_ic))
        COVARS <- NULL
        
        LAMBDA <- NULL
        for (c in Sys.glob(sprintf("%s/%s-lambda*.rds", scratch_dir, prefix_ic))){
            if (length(LAMBDA) == 0) {
                LAMBDA <- readRDS(c)
            } else {
                LAMBDA <- c(LAMBDA, readRDS(c))
            }
        }
        saveRDS(LAMBDA, sprintf("%s/%s-lambda.rds", results_dir, prefix_ic))
        LAMBDA <- NULL
        

        ## Combine deviance
        if (ic == "bic"){
            DEVIANCE <- NULL
            for (c in Sys.glob(sprintf("%s/%s-deviance*.rds", scratch_dir, prefix_ic))){
                if (length(DEVIANCE) == 0) {
                    DEVIANCE <- readRDS(c)
                } else {
                    DEVIANCE <- DEVIANCE + readRDS(c)
                }
            }
            write.table(DEVIANCE, sprintf("%s/%s-deviance.txt", results_dir, prefix_ic), 
                row.names = FALSE,  sep = "|", quote = FALSE)
            DEVIANCE <- NULL
        }
        
        ## Combining QR Dataset
        if (ic == "bic" & prefix == "" & buildQRdataset == TRUE){
            session <- readRDS(sprintf("%s/session.rds", scratch_dir))
            for(sess in unique(session)){
                first_iteration <- TRUE
                for (l in Sys.glob(sprintf("%s/QR_*_%s.rds", scratch_dir, sess))){
                    if(first_iteration == TRUE){
                        DATA <- readRDS(l)
                    } else {
                        DATA <- rbind(DATA, readRDS(l))
                    }
                    first_iteration <- FALSE
                }
                saveRDS(DATA, sprintf("%s/QR_%s.rds", results_dir, sess))
            }
        }
    }
}




