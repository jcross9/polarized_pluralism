## Used in run_mn.sbatch
testing <- ifelse(Sys.getenv("TESTING") == TRUE, TRUE, FALSE)
source("lib/mn_model/runsetup.R")
x       <- getCounts(RSnosmooth)

data <- read_csv("TBD")

Major_subsets <- data %>% group_by(Major) %>% group_split() 

preprocess <- lapply(Major_subsets, function(i) 'STUFF HAPPENS HERE TO MAKE COUNTS TK')

vocab <- readRDS("/Users/alexanderfurnas/Downloads/repo/data/vocab.rds")

vocab_split <- vocab %>% lapply(function(i) str_split(i, " ", simplify = T))

vocab_split <- vocab_split %>% unlist()

runMN(U = U, varInt = i$party, varIntfake = RSfake_nosmooth, sfun = sfun_nosmooth, counts = i$count, 
      IC = c("bic", "noc"), mu = mu, testing = testing, fixedcost = 1e-5,
      measures = c("expected_posterior", "real_posterior"))

