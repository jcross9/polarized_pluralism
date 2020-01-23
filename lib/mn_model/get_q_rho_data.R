#### getData function for building Q Rho dataset in Fit2Polar
getData <- function(q, party, sess){
  q_hat_R     <- q[which(party == 1), ]
  q_hat_D     <- q[which(party == 0), ]
  names       <- colnames(q)
  q           <- party <- NULL
  gc()
  q_hat_D     <- q_hat_D[match(rownames(q_hat_R), rownames(q_hat_D)), ]
  rho         <- q_hat_R / (q_hat_R + q_hat_D)
  
  avg_q_hat_R <- apply(q_hat_R, 2, mean)
  avg_q_hat_D <- apply(q_hat_D, 2, mean)
  avg_rho_hat <- apply(rho,     2, mean)
  avg_q_R_rho <- apply(q_hat_R * rho,       2, mean)
  avg_q_D_rho <- apply(q_hat_D * (1 - rho), 2, mean)
  q_hat_D     <- q_hat_R <- rho <- NULL
  gc()
  
  data        <- cbind(names,       rep(sess, length(avg_q_hat_R)), 
                       avg_q_hat_R, avg_q_hat_D, 
                       avg_rho_hat, avg_q_R_rho, 
                       avg_q_D_rho)
  avg_q_hat_R <- avg_q_hat_D <- avg_rho_hat <- avg_q_R_rho <- avg_q_D_rho <- NULL
  
  return(data.table(data))
}