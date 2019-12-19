import os, subprocess, argparse
execfile('lib/make/py/make_sbatch.py')

parser = argparse.ArgumentParser(description = "Create sbatch call for mn model estimation")
parser.add_argument('--test', default = False, action = 'store_true')
args = parser.parse_args()

my_dir = os.path.abspath(os.path.dirname(sys.argv[0]))
os.environ['PATHS'] = os.path.join(my_dir, 'paths.txt')
if not os.path.isfile(os.environ['PATHS']):
    raise OSError('Incorrect paths file specified:"%s"' % os.environ['PATHS'])

if args.test:
    nparts = 1
    parts_step = 1
else:
    nparts = 256
    parts_step = 8
parts_per_step = nparts / parts_step

make_sbatch(script_path = '$JOB_DIR/code.R', log_name = 'part', 
            n_array_tasks = '1-%s%%64' % nparts,
            time_per_task = '02:00:00')
make_sbatch(script_path = '$MN_SCRIPTS_DIR/get_Q_psi.R', 
            script_clarg = parts_step,
            n_array_tasks = '1-%s' % parts_per_step,
            time_per_task = '2:00:00')
make_sbatch(script_path = '$MN_SCRIPTS_DIR/combine_Q_psi.R', 
            script_clarg = parts_per_step)
make_sbatch(script_path = '$MN_SCRIPTS_DIR/Fit2Polar.R',
            n_array_tasks = '1-%s%%64' % nparts,
            time_per_task = '1:20:00')
make_sbatch(script_path = '$MN_SCRIPTS_DIR/runcombine.R',
            time_per_task = '2:00:00', partition = 'gentzkow')

if args.test:
	os.putenv('TESTING', 'TRUE')
else:
	os.putenv('TESTING', 'FALSE')

try: 
	# http://stackoverflow.com/questions/30649545/continuing-script-after-failure-on-os-system-call-python
    proc = subprocess.check_call("Rscript lib/mn_model/package_test.R", 
                                 shell = True, stdout = subprocess.PIPE, 
                                 stderr = subprocess.PIPE)
except:
    os.system('echo "ERROR: Improper version of gamlr and distrom packages' + \
    	      '\n\t need 1.13.4 and 0.3.4 respectively"')


if proc == 0:
    os.system('sh lib/mn_model/mn_model_make.sh')

