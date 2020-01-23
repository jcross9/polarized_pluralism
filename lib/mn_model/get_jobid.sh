# Extract job identifier from SLURM message passed as positional argument 1.
if ! echo $1 | grep -q "[1-9][0-9]*$"; then
   echo "Job(s) submission failed."
   echo $1
   exit 1
else
   job=$(echo $1 | grep -oh "[1-9][0-9]*$")
   echo $job
fi
