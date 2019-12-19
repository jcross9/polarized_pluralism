library(gamlr)
library(distrom)
versions <- list("gamlr" = "1.13.4", "distrom" = "0.3.4")
for (pkg in c("distrom", "gamlr")){
  if (packageVersion(pkg) < versions[pkg]) q(status = 1)
  else print(sprintf("Correct %s installed", pkg))
}
q(status = 0)
