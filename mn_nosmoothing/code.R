## Used in run_mn.sbatch
testing <- ifelse(Sys.getenv("TESTING") == TRUE, TRUE, FALSE)
source("lib/mn_model/runsetup.R")
x       <- getCounts(RSnosmooth)

data <- read_csv("TBD")

Major_subsets <- data %>% group_by(Major) %>% group_split() 

estimates <- lapply(Major_subsets, function(i) 
runMN(U = i, varInt = RSnosmooth, varIntfake = RSfake_nosmooth, sfun = sfun_nosmooth, counts = x, 
      IC = c("bic", "noc"), mu = mu, testing = testing, fixedcost = 1e-5,
      measures = c("expected_posterior", "real_posterior"))
)
