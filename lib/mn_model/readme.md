
### Overview 
- Setup to run on Midway2's `broadwl` partitions.
- These scripts are called from the root of the politext directory by scripts store in `source/analysis/mn_model_estimation/`. See subdirectory `mn/` for an example.
- `mn_model_make.sbatch` provides the outline of the R scripts used in mn estimation.
- The full dmr model fits will be stored in `$SCRATCH`, which is your personal scratch space. This directory should be cleared periodically. Use "quota" to check your storage limits.


### Code flow

Here is the code flow for scripts and helpers in this lib directory:

1. runsetup.R (functions to estimate the model, make script in `source`)
    1. setenv.R (set environment)
    2. dmrWrapper.R (wrapper around `dmr` call for estimation)
2. get_q_psi.R (compute chunks of q_denominator, psi_denominator & psi_numerator)
    1. setenv.R 
    2. utility_functions.R (functions to estimate utility from speech)
3. combine_Q_psi.R (combine chunks of q_denominator, psi_denominator & psi_numerator))
    1. setenv.R
4. Fit2Polar.R (compute likelihood and loadings)
    1. setenv.R
    2. utility_functions.R
    3. get_q_rho_data.R (store estimated q, rho, and functions of them, see [#163](https://github.com/TaddyLab/politext/issues/163))
5. runcombine.R (compute, combine, and save polarization measures)
    1. setenv.R

### Running the model

Execute the `make.py` from the root of the repository. To test the estimation procedure, include the `--test` flag after the path to the `make.py`.


### Data structure requirements 

- Phrase counts need to be stored as `data/counts/part###.txt` where ### denotes the part number; all three integer values are 
    required (ie., part 1 should be part001). The number of parts should be a multiple of 8 and can be a maximum of 256.
- The major variables (eg., U, sfun, RS) should be stored in data/covars.rda
- Requires a vocabulary list to select which phrases will be used. This can be stored anywhere and is used as an argument in the getCounts function.


### Sbatch modifications 

For the following lines of code in `runsetup.R`:

```R
$para $srun "Rscript $JOB_DIR/code.R{1} > $OUT-log/part{1}.log 2>&1 " ::: {1..ZZZ} 

$para $srun "Rscript $MN_SCRIPTS_DIR/Fit2Polar.R {1} > $OUT-log/Fit2Polar{1}.log 2>&1 " ::: {1..ZZZ}

$para $srun "Rscript $MN_SCRIPTS_DIR/get_Q_psi.R {1}  YY > $OUT-log/get_Q_psi{1}.log 2>&1 " ::: {1..XX}

Rscript $MN_SCRIPTS_DIR/combine_Q_psi.R XX > $OUT-log/combine_Q_psi.log]
```

`ZZZ` should denote the number of phrase count files for the given model (256 for the main model). `YY` is the number of parts that will be summed on a single node instance (8 for the main model). `XX` should denote the number of phrase count files `ZZZ` divided by `YY` (32 for the main model).
      

### Outline of getCounts function (stored in runsetup.R)

- Takes the variable of interest and the vocabulary list. Then parses the counts of all phrases in the 
vocabulary list and returns an object "x" that is the cleaned counts object for a given phrase count file. 


### Outline of runMN function (stored in runsetup.R)
    
```R

runMN(U, sfun, counts, mu, varInt, varIntfake = NULL, 
      IC = c("noc", "bic"), savefull = FALSE, saveQ = FALSE, 
      fixedcost = 1e-6, lmr = 1e-5,
      testing = FALSE, standardize = FALSE)
```

Required:

* **U**         - covariates, excluding varInt
* **sfun**      - matrix used to collapse loadings
* **counts**    - phrase counts per speaker-session
* **mu**        - log of a spaker-session's total phrase counts
* **varInt**    - variable of interest (truth)

Optional:

* **varIntfake**     - variable of interest (random); random fit will not be run if this is not specified
* **rand_counts**    - phrase counts per speaker-session for the random series (if different from the true series)
* **IC**             - information criterion, a vector of a subset of c("noc", "bic", "aic", "fix", "min", "1se"). By default, any subset of the first four can be used with values corresponding to c(0, log(nobs), 2, Inf). If cv_fold is not FALSE, then any subset of c("min", "1se") must be specified. They correspond to rules for choosing &lambda; through k-fold cross-validation: minimize average out-of-sample deviance and the one-standard-error rule. 
* **IC_multiplier**    - mutiplies IC by some amount
* **cv_fold**          - FALSE by default. If any other value is given dmr will use it as `k` to select &lambda; through k-fold cross-validation. So use a positive integer, and see IC.  
* **measure**        - denotes which polarization measures will be stored, can be a vector of any subset of 
                                    c("expected_posterior", "expected_loglikelihood", "expected_likelihood", "expected_loading",
                                        "real_likelihood", "real_loglikelihood", "real_posterior", "real_loading")
* **savefull**       - save full model fit in results/{SLURM_JOB_NAME}/{SLURM_JOB_ID}-data
* **saveQ**          - binary for whether the q_itj will be saved
* **buildQRdataset** - binary for whether to build QR dataset 
* **testing**        - binary for whether to run in testing mode and only use a single part
* **savecounts**     - saves counts to results folder
* **free**           - passed to dmr object
* **lambda.start**   - passed to dmr object
* **nlambda**        - passed to dmr object
* **fixedcost**      - passed to dmr object
* **lmr**            - passed to dmr object
* **standardize**    - passed to dmr object


* **bic_scratch_fit** - scratch directory for loading bic fit object for sample-splitting inference.
* **bic_k**           - overload k when computing Bayesian information criterion. Used iff bic_scratch_fit is not null. 
* **scratch_fit**     - scratch directory to load estimation fit objects. Only pass in if you want to switch your default scratch directory to an alternative path for loading fit object. Used in removing outliers for sample-splitting inference. 

### lib/mn_model/test

Test directory needs to be run from the root of the repo as `source lib/mn_model/test/make.sh`. The directory examines the output of the current mn_model to previous run with fixed data.