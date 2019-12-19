## Used in run_mn.sbatch
testing <- ifelse(Sys.getenv("TESTING") == TRUE, TRUE, FALSE)
source("lib/mn_model/runsetup.R")
x       <- getCounts(RSnosmooth)

runMN(U = U, varInt = RSnosmooth, varIntfake = RSfake_nosmooth, sfun = sfun_nosmooth, counts = x, 
      IC = c("bic", "noc"), mu = mu, testing = testing, fixedcost = 1e-5,
      measures = c("expected_posterior", "real_posterior"))
