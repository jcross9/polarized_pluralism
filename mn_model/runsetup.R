# Configure the environment for MN model estimation, load functions.
source("lib/mn_model/set_env.R")

# Load parallel part
testing <- ifelse(Sys.getenv("TESTING") == TRUE, TRUE, FALSE)
covars_path <- "data/covars.rda"
if (Sys.getenv("TESTING") == TRUE) {
    cat("TEST MODE ON\n\n")
    part <- 2 # avoid saving workspace
} else {
    covars_path <- sprintf("%s-%s", out_dir, covars_path)
    part <- as.integer(Sys.getenv('SLURM_ARRAY_TASK_ID'))
}

load(covars_path)
cat(sprintf("Loading %s\n\n", covars_path))

#### Make an R parallel cluster
makePartCluster <- function(part = NULL) {
    no_cores <- detectCores()
    if (!is.null(part)) {
        port_id <- 11000 + as.integer(part)
    }
    else {
        port_id <- NULL
    }
    cl_info <- paste(
        'Set up',
        sprintf('Node name: %s', Sys.info()['nodename']),
        sprintf('Number of cores : %s', no_cores),
        sprintf('Port Id: %d', port_id),
        sprintf('My pid: %s \n\n', Sys.getpid()),
        sep = ' \n    '
    )
    cat(cl_info)
    if (!is.null(port_id)) {
        cl <- makeCluster(
            no_cores,
            port = port_id,
            type = "FORK",
            outfile = sprintf("%s-log/cluster_%03d.log", out_dir, part)
        )
    } else {
        cl <- makeCluster(
            no_cores,
            type = "FORK",
            outfile = sprintf("%s-log/cluster_%03d.log", out_dir, part)
        )
    }
    return(cl)
}

if(exists("part")) {
    cl <- makePartCluster(part=part)
} else {
    cl <- makePartCluster()
}
baseEnvironment <- new.env()  

#### Turns raw counts into sparse matrix format to feed into DMR code
getCounts <- function(varInt, counts_location = "data/counts/") {
    

    cat(sprintf("Loading and preparing counts file: %spart%03d.txt\n\n", counts_location, part))

    if(!file.exists(sprintf("%spart%03d.txt", counts_location, part))) 
        stop("no counts file for this id")
    

    counts <- read.table(sprintf("%spart%03d.txt", counts_location, part),
                         sep        = "|", 
                         colClasses = c("character", "character", "numeric"),
                         quote      = "", 
                         comment    = "",
                         header     = TRUE)
    counts$id     <- factor(counts$id, levels = row.names(varInt))
    counts        <- counts[!is.na(counts$id), ]
    counts$phrase <- factor(counts$phrase)
    nobs          <- nrow(varInt)

    x <- sparseMatrix(i = as.numeric(counts$id), j = as.numeric(counts$phrase),
                      x = counts$x, dims = c(nobs, nlevels(counts$phrase)), 
                      dimnames = list(row.names(varInt), levels(counts$phrase)))
    return(x)
}


#### DMR call script for politext project
runMN <- function(U, sfun, counts, mu, varInt, 
                  varIntfake      = NULL, 
                  rand_counts     = NULL,
                  rand_mu         = mu,
                  IC              = c("bic"),
                  IC_multiplier   = rep(1, length(IC)),
                  cv_fold         = FALSE, 
                  cv_seed         = 2017, 
                  measures        = c("expected_posterior"),
                  savefull        = F, 
                  saveQ           = F, 
                  savecounts      = F,
                  free            = 1:ncol(U),
                  varweight       = NULL,
                  fixedcost       = 1e-6, 
                  lmr             = 1e-5, 
                  lambda.start    = Inf, 
                  nlambda         = 100,
                  standardize     = F,
                  testing         = F,
                  buildQRdataset  = F,
                  bic_scratch_fit = NULL, 
                  bic_k           = NULL,
                  scratch_fit     = NULL){

    if(length(scratch_fit)!=0){
      estimate = FALSE
    }else{
      estimate = TRUE
    }

    # Load dmr wrapper in proper lexical scope
    source("lib/mn_model/dmrWrapper.R", local = TRUE)

    # Drop observations if testing
    if (testing == TRUE) {
        keepCols <- tail(sort.int(colSums(counts), index.return = T)$ix, 3)
        counts   <- counts[, keepCols]
        use      <- c(colnames(U)[grep("Congress[0-9]+$",colnames(U))])
        U        <- U[,use]
    }    
    
    # Load information cirteria
    nobs <- nrow(varInt)
    k <- get_IC(IC, IC_multiplier, nobs, cv_fold)

    # Determine if (and with what counts) we're estimating random series
    if (length(rand_counts) == 0) {
        rand_counts <- counts
    }
    if (length(varIntfake) == 0) { 
        prefixes <- c("")
        estimate_random_series <- FALSE
    } else { 
        prefixes <- c("", "rand_")
        estimate_random_series <- TRUE
    }

    # Create landing place for polarization measures
    polar_measures <- get_polar_measures()

    # Save settings and variables to carry onto post-estimation scripts
    save(list = c("prefixes", "IC", "IC_multiplier", "saveQ", "nobs", "k", 
                  "polar_measures", "measures", "buildQRdataset", "bic_scratch_fit", "bic_k", "scratch_fit"), 
         file = sprintf("%s/settings.rda", results_dir))

    save(list = c("varInt", "varIntfake", "U", "mu", "rand_mu", "sfun"), 
         file = sprintf("%s/variables.rda", results_dir))    

    if(estimate){
      #Run DMR on true values
      cat("Running DMR on true data:\n")
      set.seed(cv_seed) # for cross validation
      dmrWrapper(varInt, counts, mu, is_fake = FALSE)

      #Run DMR on randomly assigned data
      if (estimate_random_series) {
         cat("\n\nRunning DMR on random data:\n")
         set.seed(cv_seed) # for cross validation
         dmrWrapper(varIntfake, rand_counts, rand_mu, is_fake = TRUE)
      }
    }

    stopCluster(cl) 
    cat("\n\nCluster stopped\n")
    invisible()
}


## Helper to return name and (weighted) information criteria from those specified in runMN
get_IC <- function(IC, IC_multiplier, nobs, cv_fold){
    information_criteria        <- c(0,     log(nobs), 2,     Inf)
    names(information_criteria) <- c("noc", "bic",     "aic", "fix")
    cv_criteria                 <- c(Inf,   Inf)
    names(cv_criteria)          <- c("1se", "min")
    
    # Get informatic criteria based on names passed in IC
    k <- c(information_criteria, cv_criteria)[IC]
    # Weight the informatic criteria
    k <- k * IC_multiplier
    # Append "_`weight value`" to the name if `weight value` isn't one.
    names(k) <- ifelse(IC_multiplier == 1, 
                       names(k), 
                       sprintf("%s_%s", IC[i], IC_multiplier[i]))

    # Check criteria
    selection_method <- ifelse(cv_fold, 'cross-validation', 'information criteria')
    msg <- sprintf("Penalty selection criteria (%s) are improper for penalty selection method (%s)",
                   names(k), selection_method)
    # Can't use analytic and CV penalty selection in the same run
    if ((sum(names(k) %in% names(information_criteria)) > 0) & 
        (sum(names(k) %in% names(cv_criteria)) > 0)){
        stop(msg)
    # Can't use CV penalty selection without the number of folds
    } else if ((sum(names(k) %in% names(information_criteria) == 0)) &
               (!cv_fold)){
              stop(msg)
    # Can't specify number of folds for CV if using analytic penalty selection
    } else if ((sum(names(k) %in% names(cv_criteria) == 0)) &
               (cv_fold)){
              stop(msg)
    }
    return(k)
}


## Helper to return named list for storing polarization measures, now just zeroes. 
get_polar_measures <- function(){
    polar_measures_names <- c("expected_posterior",  "expected_loglikelihood", 
                              "expected_likelihood", "expected_loading",
                              "real_likelihood",     "real_loglikelihood",     
                              "real_posterior",      "real_loading")
    polar_measures <- as.list(rep(0, length(polar_measures_names)))
    names(polar_measures) <- polar_measures_names
    return(polar_measures)
}
