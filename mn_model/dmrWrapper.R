## Wrapper around dmr call to fill in some default arguments
dmrWrapper <- function(varInt_, counts_, mu_, 
                       is_fake_      = NULL,
                       cl_           = cl,
                       U_            = U,
                       fixedcost_    = fixedcost,
                       lmr_          = lmr,
                       lambda.start_ = lambda.start, 
                       nlambda_      = nlambda,
                       free_         = free,
                       varweight_    = varweight,
                       cv_           = (cv_fold != FALSE), 
                       nfold_        = cv_fold,
                       prefixes_     = prefixes,             
                       standardize_  = standardize, 
                       savefull_     = savefull, 
                       savecounts_   = savecounts, 
                       out_dir_      = out_dir, 
                       scratch_dir_  = scratch_dir, 
                       part_         = part){
  # Estimate
  print(system.time({fit <- dmr(cl           = cl_, 
                                covars       = cBind(U_, varInt_), 
                                counts       = counts_,  
                                mu           = mu_, 
                                fixedcost    = fixedcost_, 
                                lmr          = lmr_, 
                                lambda.start = lambda.start_, 
                                nlambda      = nlambda_,
                                free         = free_,
                                varweight    = varweight_,
                                cv           = cv_, 
                                nfold        = nfold_,             
                                standardize  = standardize_)}))
  # Save estimation output
  prefix <- prefixes[1 + is_fake_]
  
  rownames(counts_)  <- rownames(varInt_)
  
  fit_file    <- sprintf("fit%03d.rds", part_)
  counts_file <- sprintf("%scounts%03d.rds", prefix, part_)
  out_dir_    <- sprintf("%s%s", out_dir, "-data")
  
  if((!is_fake_)*(savefull_)) {
    cat(sprintf("Saving fit:    %s/%s\n", out_dir_, fit_file))
    saveRDS(fit, file = sprintf("%s/%s",  out_dir_, fit_file), compress = F)
  }
  
  if((!is_fake_)*(savecounts_)) {
    cat(sprintf("Saving counts: %s/%s\n",   out_dir_, counts_file))
    saveRDS(counts_, file = sprintf("%s/%s", out_dir_, counts_file), compress = F)
  }
  
  cat(sprintf("Saving fits and counts @ %s/ \n", scratch_dir_))
  saveRDS(fit,     file = sprintf("%s/%s-%s", scratch_dir_, prefix, fit_file), compress = F)
  saveRDS(counts_, file = sprintf("%s/%s",    scratch_dir_, counts_file),      compress = F)
  
  # Free up some memory
  rm(fit)
  gc()
}
