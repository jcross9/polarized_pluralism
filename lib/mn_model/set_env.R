suppressMessages(library(methods))
suppressMessages(library(lattice))
suppressMessages(library(Matrix))
suppressMessages(library(distrom))
suppressMessages(library(dplyr))
suppressMessages(library(data.table))

options(error=traceback)

# Create standard paths from environment variables
out_dir     <- Sys.getenv("OUT")
scratch     <- Sys.getenv("SCRATCH")
scratch_dir <- sprintf("%s/%s%s", scratch, out_dir, "-data")
results_dir <- sprintf("%s%s", out_dir, "-results")
