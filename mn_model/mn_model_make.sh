#!/bin/bash


if [ $TESTING == TRUE ]; then
    export JOB_ID=test
else
    if [[ -z "$BOOT" ]]; then 
      export JOB_ID=$(date +%Y%m%d-%H%M%S)
    else
      sleep $[ $BOOT + $BOOT ]s
      export JOB_ID=$(date +%Y%m%d-%H%M%S)
    fi
fi    



#### Load environment variables (these must begin with "PATHS")

if [[ -z "$PATHS" ]]; then
    echo "Your PATHS variable does not exist."
    echo "This is likely the result of a bothched path in your make.py"
    echo "Continuing without this varaible will lead to a catastrophic 'rm -rf /'"
    echo "Fix the problem and resubmit"
    exit 1
fi

export PATHS_DATA=output/data/paths.txt
export PATHS_LIB=lib/paths.txt

source lib/make/loadpaths.sh $PATHS
source lib/make/loadpaths.sh $PATHS_DATA
source lib/make/loadpaths.sh $PATHS_LIB 

#### Start logging (do not overwrite make log is bootstrapping)
if [[ -z "$BOOT" ]]; then 
    rm -rf $OUTPUT_DIR/*
    mkdir -p $OUTPUT_DIR/
    LOG=$OUTPUT_DIR/make.log
else
    if [[ -n "$SUBMIT_STAMP" ]]; then
        export OUTPUT_DIR=$OUTPUT_DIR/$SUBMIT_STAMP 
    fi
    mkdir -p $OUTPUT_DIR/
    LOG=$OUTPUT_DIR/make_boot$BOOT.log
fi

echo "Job name:               " $JOB_NAME > $LOG
echo "Job ID:                 " $JOB_ID >> $LOG
echo "Sbatch SLURM ID:        " ${SLURM_JOBID} >> $LOG
echo "Date:                   " `date` >> $LOG
echo "Nodes:                  " $SLURM_NNODES >> $LOG
echo "Output to commit in:    " $OUTPUT_DIR >> $LOG



#### Create non-committed output space

if [ -n "$SUBMIT_TIMESTAMP" ]; then
    export RESULTS_DIR=$RESULTS_DIR/$SUBMIT_TIMESTAMP
fi
export OUT=$RESULTS_DIR/$JOB_ID
rm -rf $OUT*
mkdir -p $OUT-data
mkdir -p $OUT-log
mkdir -p $OUT-results

mkdir -p $SCRATCH/$OUT-data
echo "Output not to commit in:" $OUT >> $LOG



#### Save copies of code and data to capture their state as of run

cp -r output/data/* $OUT-log/
cp -r $JOB_DIR/* $OUT-log/
cp -r $MN_SCRIPTS_DIR/* $OUT-log/

# Full data
export DATA_DIR=data
if [[ "$DAILY" ]]; then
    # daily only
    export DATA_DIR=$DATA_DIR/daily
elif [[ "$TRIGRAM" ]]; then
    # trigram
    export DATA_DIR=$DATA_DIR/3gram
elif [[ "$PRE1940" ]]; then
    # trigram
    export DATA_DIR=$DATA_DIR/pre1940
fi

# Make the copy
cp $DATA_DIR/covars.rda $OUT-data/covars.rda




#### Execute dmr run

printf "\n----------------------------------\n\n" >> $LOG
echo "BEGIN estimation    @" `date` >> $LOG
export TMPDIR=$SCRATCH/R_temp
mkdir -p $TMPDIR
# Fit MN model
job_msg=$(sbatch $JOB_DIR/code.sbatch)
job_id=$(sh $MN_SCRIPTS_DIR/get_jobid.sh "$job_msg")
echo $job_msg
echo "RUN code.R     $job_id" >> $LOG
# Manipulate individual fits
job_msg=$(sbatch --dependency=afterany:$job_id $JOB_DIR/get_Q_psi.sbatch)
job_id=$(sh $MN_SCRIPTS_DIR/get_jobid.sh "$job_msg")
echo $job_msg
echo "RUN get_Q_psi.R     $job_id" >> $LOG
# Combine fits
job_msg=$(sbatch --dependency=afterany:$job_id $JOB_DIR/combine_Q_psi.sbatch)
job_id=$(sh $MN_SCRIPTS_DIR/get_jobid.sh "$job_msg")
echo $job_msg
echo "RUN combine_Q_psi.R $job_id" >> $LOG
# Compute polarization from fits
job_msg=$(sbatch --dependency=afterany:$job_id $JOB_DIR/Fit2Polar.sbatch)
job_id=$(sh $MN_SCRIPTS_DIR/get_jobid.sh "$job_msg")
echo $job_msg
echo "RUN Fit2Polar.R     $job_id" >> $LOG
# Pack it up nicely
job_msg=$(sbatch --dependency=afterany:$job_id $JOB_DIR/runcombine.sbatch)
job_id=$(sh $MN_SCRIPTS_DIR/get_jobid.sh "$job_msg")
echo $job_msg
echo "RUN runcombine.R    $job_id" >> $LOG
# Check the output
job_msg=$(sbatch --dependency=afterany:$job_id $MN_SCRIPTS_DIR/checksum.sbatch)
job_id=$(sh $MN_SCRIPTS_DIR/get_jobid.sh "$job_msg")
echo $job_msg
echo "RUN checksum.R    $job_id" >> $LOG
printf "\n----------------------------------\n\n" >> $LOG
printf "\n\n\n\n" >> $LOG
