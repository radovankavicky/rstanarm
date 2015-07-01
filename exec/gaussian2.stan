# GLM for a Gaussian outcome with Gaussian or t priors
functions {
  vector coefficient_vector(real alpha, vector theta, int K) {
    vector[K] beta;
    if (K != rows(theta) + 1) 
      reject("Dimension mismatch");
    beta[1] <- alpha;
    for (k in 2:K) 
      beta[k] <- theta[k-1];
      
    return beta;
  }
}
data {
  # dimensions
  int<lower=1> N; # number of observations
  int<lower=1> K; # number of predictors
  
  # data
  matrix[N,K]  X; # predictor matrix
  vector[N]    y; # continuous outcome
  
  # link function from location to linear predictor
  int<lower=1,upper=3> link; # 1 = identity, 2 = log, 3 = inverse
  
  # weights
  int<lower=0,upper=1> has_weights; # 0 = No (weights is a ones vector), 1 = Yes
  vector[N] weights;
  
  # offset
  int<lower=0,upper=1> has_offset;  # 0 = No (offset is a zero vector), 1 = Yes
  vector[N] offset;
  
  # prior distributions
  int<lower=1,upper=2> prior_dist; # 1 = normal, 2 = student_t
  int<lower=1,upper=2> prior_dist_for_intercept; # 1 = normal, 2 = student_t
  
  # hyperparameter values
  vector<lower=0>[K-1] prior_scale;
  real<lower=0> prior_scale_for_intercept;
  vector[K-1] prior_mean;
  real prior_mean_for_intercept;
  vector<lower=0>[K-1] prior_df;
  real<lower=0> prior_df_for_intercept;
  real<lower=0> prior_scale_for_dispersion;
}
parameters {
  real alpha;
  vector[K-1] theta;
  real<lower=0> sigma;
}
model {
  vector[N] eta;
  vector[K] beta;
  
  beta <- coefficient_vector(alpha, theta, K);
  eta <- X * beta;
  if (has_offset == 1) 
    eta <- eta + offset;
  
  if (has_weights == 0) { # unweighted log-likelihoods
    if (link == 1) 
      y ~ normal(eta, sigma);
    else if (link == 2) 
      y ~ lognormal(eta, sigma);
    else { # link == 3
      for (n in 1:N) eta[n] <- inv(eta[n]);
      y ~ normal(eta, sigma);
    }
  }
  else { # weighted log-likelihoods
    vector[N] summands;
    if (link == 1) {
      for (n in 1:N) 
        summands[n] <- normal_log(y[n], eta[n], sigma);
    }
    else if (link == 2) {
      for (n in 1:N) 
        summands[n] <- lognormal_log(y[n], eta[n], sigma);
    }
    else { # link == 3
      for (n in 1:N) 
        summands[n] <- normal_log(y[n], 1.0 / eta[n], sigma);
    }
    increment_log_prob(dot_product(weights, summands));
  }
  
  # log-priors
  sigma ~ cauchy(0, prior_scale_for_dispersion);
  
  if (prior_dist_for_intercept == 1) { # normal
    alpha ~ normal(prior_mean_for_intercept, prior_scale_for_intercept);
  }
  else { # student_t
    alpha ~ student_t(prior_df_for_intercept, prior_mean_for_intercept, prior_scale_for_intercept);
  }
  
  if (prior_dist == 1) { # normal
    theta ~ normal(prior_mean, prior_scale);  
  } 
  else { # student_t
    theta ~ student_t(prior_df, prior_mean, prior_scale);
  }
}
generated quantities {
  vector[K] beta;
  beta <- coefficient_vector(alpha, theta, K);
}