#### Computes likelihood, log-likelihood, posterior, and 
#### weighted loadings measures, both in expected and realized form. 

#### PRELIMINARIES

#  Define parts of counts files to operate on
if (Sys.getenv("TESTING") == TRUE) {
    part <- 2 
} else {    
    args <- commandArgs(TRUE)
    part <- as.integer(Sys.getenv('SLURM_ARRAY_TASK_ID'))
}

# Load libs, paths, and settings
source("lib/mn_model/set_env.R")
source("lib/mn_model/utility_functions.R")
source("lib/mn_model/get_q_rho_data.R")
load(sprintf("%s/settings.rda", results_dir))

# exclusion flag turn on only when scratch_fit supplied 
# meaning that we need to use other scratch fit object
if(length(scratch_fit)!=0){
    scratch_fit_dir <- sprintf("%s/%s", scratch, scratch_fit)
    exclude         <- TRUE
} else {
    scratch_fit_dir <- scratch_dir
    exclude         <- FALSE
}

if(!file.exists(sprintf("%s/-fit%03d.rds", scratch_fit_dir, part))) 
    stop("no fit for this id")


#### BEGIN 


# For real and random series
for (prefix in prefixes){
    cat(paste0("Prefix: ", prefix, "\n")) 

    load(sprintf("%s/variables.rda", results_dir))

    # Switch to random variables if we're working with the random series.
    if (prefix == "rand_"){
        varInt  <- varIntfake
        mu      <- rand_mu
    }

    # Load party and covariates. 
    pre_fit_objects <- get_pre_fit_objects(varInt, U)
    party           <- pre_fit_objects[['party']]
    newU            <- pre_fit_objects[['newU']]
    rm(pre_fit_objects)
    gc()
    
    fit     <- readRDS(sprintf("%s/%s-fit%03d.rds", scratch_fit_dir, prefix, part))
    if(length(bic_scratch_fit) != 0){
        bic_fit_dir <- sprintf("%s/%s", scratch, bic_scratch_fit)
        bic_fit     <- readRDS(sprintf("%s/%s-fit%03d.rds", bic_fit_dir, prefix, part))
    }
    
    # For each information criterion
    for(ic in IC) {
        cat(paste0("    IC: ", ic, "\n"))
        prefix_ic <- sprintf("%s%s", prefix, ic)
        if ((ic == "1se") | (ic == "min")){
            sel <- ic
        } else {
            sel <- NULL
        }    

        # calculate the deviance suming over phrases (when ic = bic); 
        if (ic == "bic"){
            getDeviance <- function(phrase){phrase$deviance[which.min(BIC(phrase))]} 
            deviance_part <- sum(unlist(lapply(fit, getDeviance)))
            saveRDS(deviance_part, file = sprintf("%s/%s-deviance%03d.rds", scratch_dir, prefix_ic, part))
        }

        ## Part specific 
        ## Prepare coefficient matrices for computation
        # Extract all coefficient estimates for utility of each phrase
        beta         <- coef(fit, select = sel, k = k[ic], corrected = FALSE)
        if (length(bic_scratch_fit) != 0){
            bic_beta <- coef(bic_fit, select = sel, k = bic_k, corrected = FALSE)
        } else {
            bic_beta = NULL
        }
        utility_list <- calculate_utility(beta, varInt, party, newU, bic_beta, exclude)
        utility_dem  <- utility_list[['utility_dem']]
        utility      <- utility_list[['utility']]
        phi          <- utility_list[['phi']]
        beta_varint  <- utility_list[['beta_varint']]
        beta_covar   <- utility_list[['beta_covar']]
        rm(utility_list)
        gc()

        # Load denominators
        q <- exp(utility) / readRDS(sprintf("%s/%s-q_denom.rds", results_dir, prefix_ic))
        psi <- as.matrix(readRDS(sprintf("%s/%s-psi.rds", results_dir, prefix_ic)))
        
        ## Realized measures
        loglikelihood_ratio <- as.vector(log(psi)) + phi
        likelihood_ratio    <- psi * exp(phi)
        posterior_prob      <- as.matrix((psi * exp(phi)) / (1 + psi * exp(phi)))
        
        if(max(grepl("real", measures))) {
          counts  <- readRDS(sprintf("%s/%scounts%03d.rds", scratch_dir, prefix, part)) 
          polar_measures[["real_posterior"]]     <- as.matrix(rowSums(posterior_prob      * counts) / exp(mu))
          polar_measures[["real_loglikelihood"]] <- as.matrix(rowSums(loglikelihood_ratio * counts) / exp(mu))        
          polar_measures[["real_likelihood"]]    <- as.matrix(rowSums(likelihood_ratio    * counts) / exp(mu))        
          polar_measures[["real_loading"]]       <- as.matrix(rowSums(phi                 * counts) / exp(mu))
        }
        
        ## Expected measures with cloning
        posterior_prob      <- rbind(posterior_prob, posterior_prob)
        loglikelihood_ratio <- rbind(as.matrix(loglikelihood_ratio), as.matrix(loglikelihood_ratio))
        likelihood_ratio    <- rbind(as.matrix(likelihood_ratio), as.matrix(likelihood_ratio))
        phi                 <- rBind(phi, phi)
        
        polar_measures[["expected_posterior"]]     <- as.matrix(rowSums(posterior_prob      * q))
        polar_measures[["expected_loglikelihood"]] <- as.matrix(rowSums(loglikelihood_ratio * q))
        polar_measures[["expected_likelihood"]]    <- as.matrix(rowSums(likelihood_ratio    * q))
        polar_measures[["expected_loading"]]       <- as.matrix(rowSums(phi                 * q))
        
        ## Save measures
        speakers        <- rownames(varInt)
        speakers_clones <- paste(speakers, "_clone", sep = "")
        speakers_w_clones  <- rbind(as.matrix(speakers), 
                                    as.matrix(speakers_clones))
        for (i in measures) {
            if (i %in% c("expected_posterior", "expected_likelihood", 
                         "expected_loglikelihood", "expected_loading")){
                rownames(polar_measures[[i]]) <- speakers_w_clones
            } else {
                rownames(polar_measures[[i]]) <- speakers
            }
            saveRDS(polar_measures[[i]], sprintf("%s/%s-%s%03d.rds", scratch_dir, prefix_ic, i, part))
        }
        
        ## Store intermediate outputs
        if (saveQ == TRUE & prefix == ""){
            saveRDS(q, file = sprintf("%s/%s-q-%03d.rds", results_dir, ic, part))
        }

        b    <- summary(beta_varint)
        b$j  <- colnames(beta_varint)[b$j]
        b$i  <- rownames(beta_varint)[b$i]
        saveRDS(b,          file = sprintf("%s/%s-beta%03d.rds",        scratch_dir, prefix_ic, part))
        saveRDS(beta_covar, file = sprintf("%s/%s-covar_coefs%03d.rds", scratch_dir, prefix_ic, part))

        if (is.null(sel)){
            lambda <- unlist(lapply(fit, function(x) x[["lambda"]][which.min(AICc(x, k = k[ic]))]))
        } else {
            lambda <- unlist(lapply(fit, function(x) x[[sprintf("lambda.%s", ic)]]))
            seg    <- unlist(lapply(fit, function(x) x[[sprintf("seg.%s",    ic)]]))
            names(lambda) <- names(seg)
        }
        saveRDS(lambda, file = sprintf("%s/%s-lambda%03d.rds", scratch_dir, prefix_ic, part))
        
        ## Build QR dataset
        if (ic == "bic" & prefix == "" & buildQRdataset == TRUE){
          party_temp <- c(party, 1 - party)
          session    <- ifelse(nchar(rownames(q)) == 9,
                                  substr(rownames(q), 1, 2),
                                  substr(rownames(q), 1, 3))
          
          data <- lapply(1:length(unique(session)), function (n) getData(q[which(session == unique(session)[n]), ],
                                              party_temp[which(session == unique(session)[n])], unique(session)[n]))
          for(i in 1:length(unique(session))){
            saveRDS(data[[i]], file = sprintf("%s/QR_%03d_%s.rds", scratch_dir, part, unique(session)[i]))
          }
          saveRDS(session, file = sprintf("%s/session.rds", scratch_dir))
        }
    }
}
