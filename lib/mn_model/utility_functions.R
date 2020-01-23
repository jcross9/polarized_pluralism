## Function used to compute utility from dmr fit objects and other variables

# Steps before loading fit
get_pre_fit_objects <- function(varInt, U){
  
  # Create congressperson x 1 matix of indicators for Republican party membership
  party  <- matrix(data = 0, nrow = length(varInt[, 1]), ncol = 1)
  party[which(rowSums(varInt) > 0), ] <- 1
  party  <- as.matrix(party)
  
  # Add an intercept at unity to congressperson covariates 
  # to match dimension of coefficient matrix
  if (length(U) == 0){ 
    newU <- as.matrix(rep(1, nrow(varInt)))
  } else {
    newU <- cbind(1, as.matrix(U))
  }
  
  out <- list(party = party, newU = newU)
  return(out)
}

# Steps after computing beta from fit and information criterion
calculate_utility <- function(beta, varInt, party, newU, bic_beta = NULL, exclude = FALSE){
  # Store coefficients separately for variables of interest and other characteristics 
  beta_varint <- beta[colnames(varInt), , drop = FALSE]
  beta_covar  <- beta[!(rownames(beta) %in% colnames(varInt)), , drop = FALSE]
  
  # Select phs in bic estimation where the coef is non-zero
  if (!is.null(bic_beta)) {
    bic_beta_varint_nonzero <- bic_beta[colnames(varInt), colnames(beta_varint), drop = FALSE] != 0 
    beta_varint             <- beta_varint * bic_beta_varint_nonzero
    if(exclude){
      if(length(beta_varint[rownames(beta_varint) == "R:058", colnames(beta_varint) == "judg swayn"])!=0){
        beta_varint[rownames(beta_varint) == "R:058", colnames(beta_varint) == "judg swayn"] <- -9999999  
      } 
      if(length( beta_varint[rownames(beta_varint) == "R:073", colnames(beta_varint) == "creek dam"])!=0){
        beta_varint[rownames(beta_varint) == "R:073", colnames(beta_varint) == "creek dam"] <- -9999999  
      } 
    }
  }
  
  # Compute phrase-time specific party loadings, columns are phrases
  phi <- sfun[, colnames(varInt), drop = FALSE] %*% beta_varint
  
  # Column bind republican indicator matrix to itself so it has num-phrases columns
  # Then clone the matrix but swap the indicator to democrats
  party_matrix       <- do.call(cbind, lapply(1:ncol(phi), function(var) party))
  party_matrix_clone <- (-party_matrix + 1)
  
  # Compute utility for each real congressperson (and their clones) of each phrase
  # We use the clone to "observe" congresspeople at the same covariates but of the other party.
  utility_dem   <- as.matrix(newU %*% beta_covar)
  utility_rep   <- as.matrix(utility_dem + phi)
  utility_real  <- as.matrix(utility_dem + party_matrix * phi)
  utility_clone <- as.matrix(utility_dem + party_matrix_clone * phi)
  utility       <- rbind(as.matrix(utility_real), as.matrix(utility_clone))
  
  out <- list(utility_dem = utility_dem, utility_rep = utility_rep, 
              utility = utility, phi = phi, 
              beta_varint = beta_varint, beta_covar = beta_covar)
  return(out)
}
