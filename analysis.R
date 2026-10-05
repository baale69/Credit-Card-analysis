# Credit card application outcomes
# Run from the repository folder. Only base R is needed.

# 1. Read and join the two data files
applicants <- read.csv("data/Credit_card.csv", na.strings = c("", "NA"))
labels <- read.csv("data/Credit_card_label.csv")
stopifnot(!anyDuplicated(applicants$Ind_ID), !anyDuplicated(labels$Ind_ID))
stopifnot(setequal(applicants$Ind_ID, labels$Ind_ID))
cards <- merge(applicants, labels, by = "Ind_ID")

# Kaggle defines label 1 as rejected and label 0 as approved.
keep <- complete.cases(cards[, c("label", "Annual_income", "Propert_Owner")])
analysis_data <- cards[keep, ]
analysis_data$income_10000 <- analysis_data$Annual_income / 10000
analysis_data$property <- factor(analysis_data$Propert_Owner,
                                levels = c("N", "Y"), labels = c("No", "Yes"))

# 2. Describe the sample
dir.create("results", showWarnings = FALSE)
sink("results/analysis_output.txt", split = TRUE)
cat("Records joined:", nrow(cards), "\n")
cat("Records excluded for missing analysis variables:", sum(!keep), "\n")
cat("Records analyzed:", nrow(analysis_data), "\n\n")
print(table(Outcome = factor(analysis_data$label, levels = c(0, 1),
                             labels = c("Approved", "Rejected"))))
print(summary(analysis_data$Annual_income))

counts <- table(analysis_data$property, analysis_data$label)
property_summary <- data.frame(Property_owner = rownames(counts),
                              Applicants = rowSums(counts),
                              Rejected = counts[, "1"],
                              Rejection_percent = 100 * prop.table(counts, 1)[, "1"])
print(property_summary)
write.csv(property_summary, "results/property_summary.csv", row.names = FALSE)

# 3. Fit a logistic regression and report adjusted odds ratios
model <- glm(label ~ income_10000 + property,
             family = binomial, data = analysis_data)
print(summary(model))
coefficients <- coef(summary(model))[-1, , drop = FALSE]
odds_ratios <- data.frame(
  Predictor = rownames(coefficients),
  Odds_ratio = exp(coefficients[, 1]),
  Lower_95 = exp(coefficients[, 1] - 1.96 * coefficients[, 2]),
  Upper_95 = exp(coefficients[, 1] + 1.96 * coefficients[, 2]),
  P_value = coefficients[, 4])
print(odds_ratios)
write.csv(odds_ratios, "results/odds_ratios.csv", row.names = FALSE)
cat("\nR version:", R.version.string, "\n")
sink()

# 4. Plot observed percentages and fitted probabilities
png("results/rejection_by_property.png", width = 1400, height = 1000, res = 160)
par(mar = c(5, 5, 4, 2))
positions <- barplot(property_summary$Rejection_percent,
                     names.arg = c("No", "Yes"), col = c("#426B8A", "#459B91"),
                     ylim = c(0, 20), ylab = "Applications rejected (%)",
                     xlab = "Property owner", main = "Observed rejection percentages")
text(positions, property_summary$Rejection_percent + 1,
     labels = sprintf("%.1f%%", property_summary$Rejection_percent))
dev.off()

# Show the middle 90% of income values to keep the figure readable.
income_range <- quantile(analysis_data$Annual_income, c(0.05, 0.95))
prediction_data <- expand.grid(
  income_10000 = seq(income_range[1], income_range[2], length.out = 100) / 10000,
  property = levels(analysis_data$property))
prediction_data$probability <- predict(model, prediction_data, type = "response")
png("results/fitted_probabilities.png", width = 1400, height = 1000, res = 160)
par(mar = c(5, 5, 4, 2))
plot(probability ~ income_10000, data = subset(prediction_data, property == "No"),
     type = "l", lwd = 3, col = "#426B8A", ylim = c(0, 0.2),
     xlab = "Annual income (10,000 recorded currency units)",
     ylab = "Estimated probability of rejection", main = "Fitted logistic regression")
lines(probability ~ income_10000, data = subset(prediction_data, property == "Yes"),
      lwd = 3, col = "#459B91")
legend("topright", c("Does not own property", "Owns property"),
       col = c("#426B8A", "#459B91"), lwd = 3, bty = "n")
dev.off()
