export prefix=lib/mn_model/test
export LOG=$prefix/make.log
export OUT=$prefix/output
export SCRATCH=$prefix/scratch

rm $LOG
mkdir -p $OUT-data
mkdir -p $OUT-log
mkdir -p $OUT-results
mkdir -p $SCRATCH/$OUT-data

echo "Starting at " $(date +%D:%H:%M:%S) >> $LOG

export TESTING=TRUE

Rscript $prefix/run_suite.R >> $LOG 2>&1

rm -rf $OUT-data
rm -rf $OUT-log
rm -rf $OUT-results
rm -rf $SCRATCH

echo "Finished at " $(date +%D:%H:%M:%S) >> $LOG
