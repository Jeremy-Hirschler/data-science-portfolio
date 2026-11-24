library(xtable)
# Better
library(truncnorm)
library(ggplot2)
library(pscl)
library(MASS)
library(Metrics)

library(dplyr)
library(ggplot2)
library(tidyr)



generate_zip_data <- function(n = 1000, seed = 123) {
  set.seed(seed)
  
  # --- Step 1: Generate covariates ---
  age <- sample(18:90, n, replace = TRUE)            # Age: roughly adult population
  gender <- rbinom(n, 1, 0.5)                    # Gender: 0 = female, 1 = male
  smoking <- factor(sample(1:3, n, replace=TRUE),
                    levels=1:3,
                    labels = c("nonsmoker", "sometimes", "often"))      # Smoking: 1 = nonsmoker, 2 = sometimes, 3 = often
  
  # --- Step 2: Construct linear predictors for Poisson mean and zero inflation ---
  # Design matrix (intercept + covariates)
  X <- model.matrix(~ age + gender + smoking)
  
  # Coefficients
  beta_count <- c(-1.2, 0.02, -0.1, 0.1, 0.2)    # For Poisson mean (log link)
  beta_zero  <- c(-1.5, -0.02, 0.6, -0.2, -0.3)   # For structural zero (logit link)
  
  # Expected value for Poisson
  lambda <- exp(X %*% beta_count)
  
  # Probability of being a structural zero
  p_zero <- plogis(X %*% beta_zero)
  
  # Bernoulli trial for structural zeros
  structural_zero <- rbinom(n, 1, p_zero)
  
  # Count outcome
  count <- ifelse(structural_zero == 1, 0, rpois(n, lambda))
  
  # Return dataset
  df <- data.frame(
    age = age,
    gender = gender,
    smoking = smoking,
    count = count
  )
  
  return(df)
}

df <- generate_zip_data(n = 1000)

head(df)
table(df$count)
summary(df)

xtable(summary(df))


count_freq <- as.data.frame(table(df$count))
colnames(count_freq) <- c("Count", "Frequency")
xtable(count_freq, caption = "Frequency of Doctor Visit Counts")

ggplot(df, aes(x = count)) +
  geom_bar(fill = "skyblue", color = "black") +
  labs(title = "Histogram of Doctor Visit Counts",
       x = "Number of Visits",
       y = "Frequency")

# Save as PDF for Overleaf
ggsave("count_histogram.pdf", width = 6, height = 4)


#Run models
poisson_model <- glm(count ~ age + gender + smoking,
                     family = poisson(link="log"),
                     data = df)
summary(poisson_model)

zip_model <- zeroinfl(count ~ age + gender + smoking | age + gender + smoking,
                      data = df, dist = "poisson")
summary(zip_model)

hurdle_model <- hurdle(count ~ age + gender + smoking | age + gender + smoking,
                       data = df, dist = "poisson")
summary(hurdle_model)

#Model Comparisons



# AIC & Log-likelihood
model_metrics <- data.frame(
  Model = c("Poisson", "ZIP", "Hurdle"),
  AIC = c(AIC(poisson_model), AIC(zip_model), AIC(hurdle_model)),
  BIC = c(BIC(poisson_model), BIC(zip_model), BIC(hurdle_model)),
  LogLik = c(logLik(poisson_model), logLik(zip_model), logLik(hurdle_model))
)

# Vuong Test for ZIP vs Poisson
vuong_result <- vuong(zip_model, hurdle_model)

# Percentage of zeros in data
obs_zero_pct <- mean(df$count == 0)

# Predicted zeros

# Observed zero rate
obs_zero_pct <- mean(df$count == 0)

# Poisson model
poisson_zero_pct <- mean(exp(-predict(poisson_model, type = "response")))

# ZIP model
zip_lambda <- predict(zip_model, type = "count")
zip_structural <- predict(zip_model, type = "zero")
zip_zero_probs <- zip_structural + (1 - zip_structural) * exp(-zip_lambda)
zip_zero_pct <- mean(zip_zero_probs)

# Hurdle model
hurdle_zero_pct <- mean(1 - predict(hurdle_model, type = "zero"))

#plots


# Response-level predictions (fitted counts)
poisson_preds <- predict(poisson_model, type = "response")
zip_preds     <- predict(zip_model, type = "response")
hurdle_preds  <- predict(hurdle_model, type = "response")


# MAE
mae_poisson <- mae(df$count, poisson_preds)
mae_zip     <- mae(df$count, zip_preds)
mae_hurdle  <- mae(df$count, hurdle_preds)

# RMSE
rmse_poisson <- rmse(df$count, poisson_preds)
rmse_zip     <- rmse(df$count, zip_preds)
rmse_hurdle  <- rmse(df$count, hurdle_preds)

error_df <- data.frame(
  Model = c("Poisson", "ZIP", "Hurdle"),
  MAE = c(mae_poisson, mae_zip, mae_hurdle),
  RMSE = c(rmse_poisson, rmse_zip, rmse_hurdle)
)

print(error_df)



df$poisson_pred <- predict(poisson_model, type = "response")
df$zip_pred <- predict(zip_model, type = "response")
df$hurdle_pred <- predict(hurdle_model, type = "response")


# Bin actual count values and compute average predictions
df_plot <- df %>%
  mutate(count = as.factor(count)) %>%
  group_by(count) %>%
  summarise(
    Poisson = mean(poisson_pred),
    ZIP     = mean(zip_pred),
    Hurdle  = mean(hurdle_pred),
    n       = n()
  ) %>%
  pivot_longer(cols = c(Poisson, ZIP, Hurdle), names_to = "Model", values_to = "AvgPred")

ggplot(df_plot, aes(x = count, y = AvgPred, fill = Model)) +
  geom_col(position = "dodge") +
  labs(title = "Average Predicted Value by Observed Count",
       x = "Observed Count",
       y = "Average Predicted Value")






















