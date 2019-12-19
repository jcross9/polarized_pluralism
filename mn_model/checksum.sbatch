#!/bin/bash

#SBATCH --job-name=checksum
#SBATCH --time=10:00
#SBATCH --partition=gentzkow,hns,normal,owners
#SBATCH --cpus-per-task=1
#SBATCH --ntasks=1

echo "BEGIN CHECKSUMS" >> $LOG
export CHECKSUM_DIR=$OUT-results/
srun --output=$OUTPUT_DIR/checksum.log Rscript lib/make/checksum.R

