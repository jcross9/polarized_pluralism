
test.mnFullRun <- function() {

    dir <- "lib/mn_model/test"
    
    source(sprintf("%s/runsetup.R", dir))
    x <- getCounts(RSnosmooth)
    
    # run on testing mode
    system.time(
                runMN(
                      U = U, 
                 varInt = RSnosmooth, 
             varIntfake = RSfake_nosmooth, 
                   sfun = sfun_nosmooth, 
                 counts = x, 
                     mu = mu,
                     IC = "bic",
                testing = TRUE))
    
    # post-estimation
    source(sprintf("%s/get_Q_psi.R",     dir))
    source(sprintf("%s/combine_Q_psi.R", dir))
    source(sprintf("%s/Fit2Polar.R",     dir)) 
    source(sprintf("%s/runcombine.R",    dir))

    # Start testing outputs
    benchmark_files <- list.files('input')

    for (file in benchmark_files){
        if (grepl('.txt', file)){
            benchmark <- read.table(sprintf('input/%s', file), header = T, sep = "|")
            test      <- read.table(sprintf('output-results/%s', file), header = T, sep = "|")
        } else {
            benchmark <- readRDS(sprintf('input/%s', file))
            test      <- readRDS(sprintf('output-results/%s', file))
        }
        checkEquals(sum(benchmark != test), 0)
    }

    print("Package Versions:")
    for (pkg in c("distrom", "gamlr")){
        print(sprintf("%s version: %s", pkg, packageVersion(pkg)))
    }
}
