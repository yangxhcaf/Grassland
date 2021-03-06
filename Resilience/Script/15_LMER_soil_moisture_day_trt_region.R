###################################################################################
## This script fits a linear model of the soil mositure resilience measure with  ##
## the fixed effect Day (days since the end of the simulated drought; covariate) ##
## treatment (Control vs. Drought) and Region (Border, Cork, Dublin, Limerick)   ##
## and with random effects Day (see above) and Farm (1-5)                        ##
## The response is the ratio of soil moisture in each plot to the average of the ##
## control plots at the same site (farm) and time step.                          ##
##                                                                               ##
## Author of the script:                                                         ##
## Maja Ilic M.Ilic@qub.ac.uk                                                    ##
## first modified: 04 Mar 2020                                                   ##
## last modified: 05 Mar 2020                                                    ##
###################################################################################

#================================================
# Clear objects from the workspace ----

rm(list = ls())

#================================================
# Set working directory ----

# Maja's desktop PC

setwd("C:/Users/3054311/Documents/My Documents/Grassland project/05_Resilience")

data.dir <- paste0(getwd(),"/Data/")
figures.dir <- paste0(getwd(),"/Figures/SOIL MOISTURE/")
script.dir <- paste0(getwd(),"/Script/")

#================================================
# Packages ----

library(ggplot2)
library(lubridate)
library(dplyr)
library(tidyr)
library(stringr)
library(lme4)
library(rcompanion)
library(car)
library(performance)
library(insight)
library(see)
library(grid)
library(cowplot)
library(patchwork)
library(gridExtra)
library(effects)
library(afex)
library(RColorBrewer)

#================================================
# Set directory for data and plots ----

dir.create(paste0(figures.dir,"LMER model soil moisture day trt region"))

mydir.data <- data.dir
mydir <- paste0(figures.dir,"LMER model soil moisture day trt region")

#================================================
# Functions for plots ----

# Histogram with Gaussian curve, Shapiro's test p-value, median, mean, variance and SD of x

source("C:/Users/3054311/Documents/My Documents/Grassland project/Functions/Function ggHistNorm.R")

## qqPlot made with ggplot

source("C:/Users/3054311/Documents/My Documents/Grassland project/Functions/Function ggQQplot.R")

#================================================
# Load soil moisture ratios ----

load(file = paste0(mydir.data,"Soil_moisture_resilience.RData"))

#================================================
# Prepare data for the model

resilience_soil <- moisture.window[,c(1,3,4,5,7,10)]

resilience_soil$treatment <- gsub("C", "Control", 
                                as.character(resilience_soil$treatment))

resilience_soil$treatment <- gsub("D", "Drought", 
                                as.character(resilience_soil$treatment))

resilience_soil$treatment <- as.factor(resilience_soil$treatment)
resilience_soil$Region <- as.factor(resilience_soil$Region)
resilience_soil$Farm <- as.factor(resilience_soil$Farm)

resilience_soil <- resilience_soil %>% rename(plot_meanC_ratio = Ratio)

resilience_soil <- resilience_soil[!is.na(resilience_soil$plot_meanC_ratio),]

# Define response variable 

resp.variable <- "Soil moisture ratio"

#================================================
# Model assumptions ----

title.model <- "lmer(plot_meanC_ratio ~ Day*treatment*Region + (1|Day) + (1|Farm))"

# Check for normal distribution within each region and treatment

region <- unique(resilience_soil$Region)
trt <- unique(resilience_soil$treatment)

for(i in 1:length(region)){
  
  # Extract relevant data for the respective region and treatment
  
  resilience_C <- resilience_soil %>% filter(Region == region[i] & treatment == "Control") %>% droplevels()
  resilience_D <- resilience_soil %>% filter(Region == region[i] & treatment == "Drought") %>% droplevels()
  
  region_resilience <- resilience_soil %>% filter(Region == region[i]) %>% droplevels()
  
  # Use function ggHistNorm
  
  check.norm.C <- ggHistNorm(resilience_C, resilience_C$plot_meanC_ratio, 
                             paste0(resp.variable," - ",region[i],", Control plots"), 0.05)
  
  plot.norm.C <- check.norm.C[1][[1]]
  
  check.norm.D <- ggHistNorm(resilience_D, resilience_D$plot_meanC_ratio, 
                             paste0(resp.variable," - ",region[i],", Drought plots"), 0.05)
  
  plot.norm.D <- check.norm.D[1][[1]]
  
  # Use function ggQQplot
  
  plot.qq.C <- ggQQplot(resilience_C, resilience_C$plot_meanC_ratio, 
                        paste(resp.variable," - ",region[i],", Control plots"))
  
  plot.qq.D <- ggQQplot(resilience_D, resilience_D$plot_meanC_ratio, 
                        paste(resp.variable," - ",region[i],", Drought plots"))
  
  
  # Combine all four plots in one figure
  
  figure.title.region <- paste0(mydir,"/Model assumptions - Soil moisture ratio vs Day, Trt and Region ",region[i],".png")
  
  final.plot.region <- grid.arrange(plot.norm.C,
                                    plot.qq.C,
                                    plot.norm.D,
                                    plot.qq.D) 
  
  final.plot.region <- grid.arrange(final.plot.region,
                                    top = tableGrob(t(title.model),
                                                    theme = ttheme_minimal(padding = unit(c(0,8),'mm'),
                                                                           base_colour = "black",
                                                                           base_size = 16)))
  
  ggsave(figure.title.region,
         grid.arrange(arrangeGrob(final.plot.region,
                                  top = textGrob(t(resp.variable),
                                                 gp = gpar(fontsize = 18, fontface = "bold")))),
         width = 25, height = 27, units = "cm")
  
  # Remove all objects
  
  rm(region_resilience,
     figure.title.region,
     final.plot.region, 
     plot.norm.C,
     plot.qq.C,
     plot.norm.D,
     plot.qq.D)  
}

#================================================
# Fit a model ----

# Fit a model of the ratio of the plot to the mean of the control plots as 
# a function Day since end of drought (numeric), treatment (Control vs Drought) 
# and Region (Border, Cork, Dublin and Limerick)
# Random factors included: Day (1|day) and Farm (1-5)

lmer_full_mod <- lmer(plot_meanC_ratio ~ Day*treatment*Region + (1|Day) + (1|Farm),
                      data = resilience_soil)

#================================================
# Add fitted values and residuals to the raw data ----

resilience_mod <- data.frame(resilience_soil, "Fitted" = fitted(lmer_full_mod))  
resilience_mod$Residuals <- residuals(lmer_full_mod)

#================================================
# Run anova() and extract the results ----

aov_mod <- as.data.frame(anova(lmer_full_mod))
aov_mod$Term <- rownames(aov_mod)
aov_mod <- aov_mod[,c(7,1:6)]
names(aov_mod)[2:7] <- c("Sum.Sq","Mean.Sq","NumDF","DenDF","F.value","p.value")
rownames(aov_mod) <- 1:nrow(aov_mod)

#================================================
# Extract model coefficients ----

# Fixed

coeff_fixef <- summary(lmer_full_mod)$coefficients
rownames_fixef <- data.frame("Term" = rownames(coeff_fixef))
dimnames(coeff_fixef)[[2]] <- c("Estimate","Std.Error","DF","t.value","p.value")
fixef_out <- cbind(rownames_fixef, coeff_fixef)
rownames(fixef_out) <- rownames(rownames_fixef)

# Random: Farm ----

coeff_random.1 <- ranef(lmer_full_mod)$`Farm`
rownames_random.1 <- rownames(coeff_random.1)
random_out.1 <- data.frame("Farm" = rownames_random.1, "Intercept" = coeff_random.1$`(Intercept)`)
random_out.1$Intercept_C <- random_out.1$Intercept + fixef_out$Estimate[fixef_out$Term == "(Intercept)"] 
random_out.1$Intercept_D <- random_out.1$Intercept + fixef_out$Estimate[fixef_out$Term == "(Intercept)"] + fixef_out$Estimate[fixef_out$Term == "treatmentDrought"]
random_out.1$Intercept_Border <- random_out.1$Intercept + fixef_out$Estimate[fixef_out$Term == "(Intercept)"]
random_out.1$Intercept_Cork <- random_out.1$Intercept + fixef_out$Estimate[fixef_out$Term == "(Intercept)"] + fixef_out$Estimate[fixef_out$Term == "RegionCork"]
random_out.1$Intercept_Dublin <- random_out.1$Intercept + fixef_out$Estimate[fixef_out$Term == "(Intercept)"] + fixef_out$Estimate[fixef_out$Term == "RegionDublin"]
random_out.1$Intercept_Limerick <- random_out.1$Intercept + fixef_out$Estimate[fixef_out$Term == "(Intercept)"] + fixef_out$Estimate[fixef_out$Term == "RegionLimerick"]

# Random: Day ----

coeff_random.2 <- ranef(lmer_full_mod)$Day
rownames_random.2 <- rownames(coeff_random.2)
random_out.2 <- data.frame("Day" = rownames_random.2, "Intercept" = coeff_random.2$`(Intercept)`)
random_out.2$Intercept_1 <- random_out.2$Intercept + fixef_out$Estimate[fixef_out$Term == "(Intercept)"] 

#================================================
# Model validation ----

ylab <- expression(paste(bold("Ratio"~"Plot"[bolditalic("i")]~":"~"Control"[bolditalic("mean")])))

# Observed vs fitted values ----

# ~ Day

obs.fit.day <- ggplot(resilience_mod, aes(x = Fitted, y = plot_meanC_ratio, fill = as.factor(Day))) +
  geom_point(shape = 21, size = 2, alpha = 0.5, color = "grey50") +
  facet_wrap(~ Day, ncol = 5) +
  geom_abline(slope = 1, intercept = 0) +
  theme_minimal() +
  theme(strip.background = element_rect(color = "grey50"),
        legend.position = "none",
        axis.title = element_text(size = 12, face = "bold")) +
  scale_fill_brewer(palette = "BuPu") +
  labs(x = "\nFitted",
       y = ylab,
       title = "Observed vs. Fitted",
       subtitle = "~ Day")

# ~ treatment

obs.fit.trt <- ggplot(resilience_mod, aes(x = Fitted, y = plot_meanC_ratio, 
                                          color = treatment, fill = treatment)) +
  geom_point(shape = 21, size = 2, alpha = 0.5) +
  facet_wrap(~ treatment, ncol = 2) +
  geom_abline(slope = 1, intercept = 0) +
  theme_minimal() +
  theme(strip.background = element_rect(color = "grey50"),
        legend.position = "none",
        axis.title = element_text(size = 12, face = "bold")) +
  scale_fill_manual(values = c("blue","red")) +
  scale_color_manual(values = c("blue","red")) +
  labs(x = "\nFitted",
       y = ylab,
       title = "Observed vs. Fitted",
       subtitle = "~ treatment")

# ~ Region

obs.fit.region <- ggplot(resilience_mod, aes(x = Fitted, y = plot_meanC_ratio, 
                                             color = Region, fill = Region)) +
  geom_point(shape = 21, size = 2, alpha = 0.5) +
  facet_wrap(~ Region, ncol = 2) +
  geom_abline(slope = 1, intercept = 0) +
  theme_minimal() +
  theme(strip.background = element_rect(color = "grey50"),
        legend.position = "none",
        axis.title = element_text(size = 12, face = "bold")) +
  labs(x = "\nFitted",
       y = ylab,
       title = "Observed vs. Fitted",
       subtitle = "~ Region")

# ~ Farm

obs.fit.farm <- ggplot(resilience_mod, aes(x = Fitted, y = plot_meanC_ratio, fill = Farm)) +
  geom_point(shape = 21, size = 2, alpha = 0.5, color = "grey50") +
  scale_fill_brewer(palette = "GnBu") +
  facet_wrap(~ Farm, ncol = 3) +
  geom_abline(slope = 1, intercept = 0) +
  theme_minimal() +
  theme(strip.background = element_rect(color = "grey50"),
        legend.position = "none",
        axis.title = element_text(size = 12, face = "bold")) +
  labs(x = "\nFitted",
       y = ylab,
       title = "Observed vs. Fitted",
       subtitle = "~ Farm")

#================================================
# Collinearity ----

result.coll <- check_collinearity(lmer_full_mod)

result.coll[which(result.coll$VIF < 5),"Correlation"] <- "low"
result.coll[which(result.coll$VIF >= 5 & result.coll$VIF < 10),"Correlation"] <- "moderate"
result.coll[which(result.coll$VIF >= 10),"Correlation"] <- "high"

result.coll$Correlation <- as.factor(result.coll$Correlation)
result.coll$Correlation <- factor(result.coll$Correlation, levels = c("low", "moderate", "high"))

mycol.coll <- c(rgb(39, 174, 96, max = 255),
                rgb(230, 126, 34, max = 255),
                rgb(228, 26, 28, max = 255))

corr.levels <- unique(result.coll$Correlation)

mycol <- c()

if ("low" %in% corr.levels){
  mycol <- mycol.coll[1]
}

if ("moderate" %in% corr.levels){
  mycol <- c(mycol,mycol.coll[2])
}

if ("high" %in% corr.levels){
  mycol <- c(mycol,mycol.coll[3])
}

plot.coll <- ggplot(result.coll, aes(x = Parameter, y = VIF)) +
  geom_bar(stat = "identity", width = 0.7, aes(fill = Correlation)) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1)) +
  scale_fill_manual(values = mycol) +
  labs(x = "\nParameter", y = "VIF", title = "Check for Multicollinearity", subtitle = "")

#================================================
# Residuals ----
# Binned residuals
# Function binned_residuals produces a plot if not saved to an object
# However, that plot can't be further modified
# Therefore, I save the output to an object and recreated the plot 

result.binned <- binned_residuals(lmer_full_mod)
resid.inside.err <- sum(result.binned$group == "yes")/nrow(result.binned)*100
resid.inside.err <- round(resid.inside.err, digits = 2)

plot.binned <- ggplot(result.binned, aes(x = xbar*100, y = ybar)) +
  geom_ribbon(aes(ymin = -Inf, ymax = -se),
              color = "grey80", fill = "grey95", alpha = 0.5) +
  geom_ribbon(aes(ymin = se, ymax = +Inf),
              color = "grey80", fill = "grey95", alpha = 0.5) +
  geom_hline(yintercept = 0, color = "grey80") +
  geom_point(aes(color = group), size = 3) +
  theme_bw() +
  scale_color_brewer(palette = "Set1") + 
  labs(x = paste0("\nEstimated probability of ", resp.variable), 
       y = "Average residual", 
       title = "Binned residuals", 
       subtitle = paste0(resid.inside.err, "% of the residuals are inside the error bounds."))

# ~ Fitted

result.heteroscedasticity <- check_heteroscedasticity(lmer_full_mod)

if(result.heteroscedasticity[1] < 0.001){
  p.res.fit <- "p < 0.001"
}

if(result.heteroscedasticity[1] >= 0.001 & result.heteroscedasticity[1] < 0.01){
  p.res.fit <- "p < 0.01"
}

if(result.heteroscedasticity[1] >= 0.01 & result.heteroscedasticity[1] < 0.05){
  p.res.fit <- "p < 0.05"
}

if(result.heteroscedasticity[1] >= 0.05 ){
  p.res.fit <- parse(text = paste0('p == ', round(result.heteroscedasticity[1], digits = 3)))
}

plot.res.fit <- ggplot(resilience_mod, aes(x = Fitted, y = Residuals)) +
  geom_point(size = 2, color = rgb(44, 62, 80, max = 255)) +
  theme_minimal() +
  geom_smooth(method = "loess", size = 1, color = rgb(228, 26, 28, max = 255), se = F) +
  labs(x = "\nFitted",
       y = "Residuals",
       title = "Residuals vs. Fitted",
       subtitle = p.res.fit)

# ~ Day

RESID_var_day <- leveneTest(Residuals ~ as.factor(Day), data = resilience_mod)

if(RESID_var_day$`Pr(>F)`[1] < 0.001){
  main.day <- "p < 0.001"
}

if(RESID_var_day$`Pr(>F)`[1] >= 0.001 & RESID_var_day$`Pr(>F)`[1] < 0.01){
  main.day <- "p < 0.01"
}

if(RESID_var_day$`Pr(>F)`[1] >= 0.01 & RESID_var_day$`Pr(>F)`[1] < 0.05){
  main.day <- "p < 0.05"
}

if(RESID_var_day$`Pr(>F)`[1] >= 0.05 ){
  main.day <- parse(text = paste0('p == ', round(RESID_var_day$`Pr(>F)`[1], digits = 3)))
}

box.day <- ggplot(resilience_mod, aes(x = as.factor(Day), 
                                      y = Residuals, 
                                      fill = as.factor(Day))) +
  geom_boxplot(outlier.shape = 21) +
  theme_minimal() +
  theme(legend.position = "none",
        axis.title = element_text(size = 12, face = "bold")) +
  scale_fill_brewer(palette = "BuPu") +
  labs(x = "\nDays since the end of the simulated drought",
       y = "Residuals",
       title = "Residuals ~ Day",
       subtitle = main.day)

# ~ treatment

RESID_var_trt <- leveneTest(Residuals ~ treatment, data = resilience_mod)

if(RESID_var_trt$`Pr(>F)`[1] < 0.001){
  main.trt <- "p < 0.001"
}

if(RESID_var_trt$`Pr(>F)`[1] >= 0.001 & RESID_var_trt$`Pr(>F)`[1] < 0.01){
  main.trt <- "p < 0.01"
}

if(RESID_var_trt$`Pr(>F)`[1] >= 0.01 & RESID_var_trt$`Pr(>F)`[1] < 0.05){
  main.trt <- "p < 0.05"
}

if(RESID_var_trt$`Pr(>F)`[1] >= 0.05 ){
  main.trt <- parse(text = paste0('p == ', round(RESID_var_trt$`Pr(>F)`[1], digits = 3)))
}

box.trt <- ggplot(resilience_mod, aes(x = treatment, y = Residuals, fill = treatment)) +
  geom_boxplot(outlier.shape = 21) +
  theme_minimal() +
  theme(legend.position = "none",
        axis.title = element_text(size = 12, face = "bold")) +
  scale_fill_manual(values = c("blue","red")) +
  labs(x = "\ntreatment",
       y = "Residuals",
       title = "Residuals ~ treatment",
       subtitle = main.trt)

# ~ Region

RESID_var_region <- leveneTest(Residuals ~ Region, data = resilience_mod)

if(RESID_var_region$`Pr(>F)`[1] < 0.001){
  main.region <- "p < 0.001"
}

if(RESID_var_region$`Pr(>F)`[1] >= 0.001 & RESID_var_region$`Pr(>F)`[1] < 0.01){
  main.region <- "p < 0.01"
}

if(RESID_var_region$`Pr(>F)`[1] >= 0.01 & RESID_var_region$`Pr(>F)`[1] < 0.05){
  main.region <- "p < 0.05"
}

if(RESID_var_region$`Pr(>F)`[1] >= 0.05 ){
  main.region <- parse(text = paste0('p == ', round(RESID_var_region$`Pr(>F)`[1], digits = 3)))
}

box.region <- ggplot(resilience_mod, aes(x = Region, y = Residuals, fill = Region)) +
  geom_boxplot(outlier.shape = 21, alpha = 0.7) +
  theme_minimal() +
  theme(legend.position = "none",
        axis.title = element_text(size = 12, face = "bold")) +
  labs(x = "\nRegion",
       y = "Residuals",
       title = "Residuals ~ Region",
       subtitle = main.region)

# ~ Farm

RESID_var_farm <- leveneTest(Residuals ~ Farm, data = resilience_mod)

if(RESID_var_farm$`Pr(>F)`[1] < 0.001){
  main.farm <- "p < 0.001"
}

if(RESID_var_farm$`Pr(>F)`[1] >= 0.001 & RESID_var_farm$`Pr(>F)`[1] < 0.01){
  main.farm <- "p < 0.01"
}

if(RESID_var_farm$`Pr(>F)`[1] >= 0.01 & RESID_var_farm$`Pr(>F)`[1] < 0.05){
  main.farm <- "p < 0.05"
}

if(RESID_var_farm$`Pr(>F)`[1] >= 0.05 ){
  main.farm <- parse(text = paste0('p == ', round(RESID_var_farm$`Pr(>F)`[1], digits = 3)))
}

box.farm <- ggplot(resilience_mod, aes(x = Farm, y = Residuals, fill = Farm)) +
  geom_boxplot(outlier.shape = 21, alpha = 0.7) +
  scale_fill_brewer(palette = "GnBu") +
  theme_minimal() +
  theme(legend.position = "none",
        axis.title = element_text(size = 12, face = "bold")) +
  labs(x = "\nFarm",
       y = "Residuals",
       title = "Residuals ~ Farm",
       subtitle = main.farm)

#================================================
# Check for normal distribution of residuals ----

check.norm.resid <- ggHistNorm(resilience_mod, resilience_mod$Residuals, "Residuals", 0.05)
plot.norm.resid <- check.norm.resid[1][[1]]

plot.qq.resid <- ggQQplot(resilience_mod, resilience_mod$Residuals, "Residuals")

# Check for normal distribution within each region and treatment

region <- unique(resilience_mod$Region)
trt <- unique(resilience_mod$treatment)

for(i in 1:length(region)){
  
  # Extract relevant data for the respective region and treatment
  
  resilience_C <- resilience_mod %>% filter(Region == region[i] & treatment == "Control") %>% droplevels()
  resilience_D <- resilience_mod %>% filter(Region == region[i] & treatment == "Drought") %>% droplevels()
  
  region_resilience <- resilience_mod %>% filter(Region == region[i]) %>% droplevels()
  
  # Use function ggHistNorm
  
  check.norm.resid.C <- ggHistNorm(resilience_C, resilience_C$Residuals, 
                                   paste0("Residuals - ",region[i],", Control plots"), 0.05)
  
  plot.norm.resid.C <- check.norm.resid.C[1][[1]]
  
  check.norm.resid.D <- ggHistNorm(resilience_D, resilience_D$Residuals, 
                                   paste0("Residuals - ",region[i],", Drought plots"), 0.05)
  
  plot.norm.resid.D <- check.norm.resid.D[1][[1]]

  # Use function ggQQplot
  
  plot.qq.resid.C <- ggQQplot(resilience_C, resilience_C$Residuals, 
                              paste("Residuals - ",region[i],", Control plots"))
  
  plot.qq.resid.D <- ggQQplot(resilience_D, resilience_D$Residuals, 
                              paste("Residuals - ",region[i],", Drought plots"))
    
    
  # Combine all four plots in one figure
  
  figure.title.region <- paste0(mydir,"/Model validation - Residuals vs Day, Trt and Region ",region[i],".png")
  
  final.plot.region <- grid.arrange(plot.norm.resid.C,
                                    plot.qq.resid.C,
                                    plot.norm.resid.D,
                                    plot.qq.resid.D) 
  
  final.plot.region <- grid.arrange(final.plot.region,
                                    top = tableGrob(t(title.model),
                                                    theme = ttheme_minimal(padding = unit(c(0,8),'mm'),
                                                                           base_colour = "black",
                                                                           base_size = 16)))
  
  ggsave(figure.title.region,
         grid.arrange(arrangeGrob(final.plot.region,
                                  top = textGrob(t(resp.variable),
                                                 gp = gpar(fontsize = 18, fontface = "bold")))),
         width = 25, height = 27, units = "cm")
  
  # Remove all objects
  
  rm(region_resilience,
     figure.title.region,
     final.plot.region, 
     plot.norm.resid.C,
     plot.qq.resid.C,
     plot.norm.resid.D,
     plot.qq.resid.D)  
}

#================================================
# Normality of Random Effects ----

result.mod <- check_model(lmer_full_mod)

# ~ Day

REQQ.day <- result.mod$REQQ$Day

reqq.plot.day <- ggplot(REQQ.day, aes(x = x, y = y)) +
  geom_point(size = 2, color = rgb(44, 62, 80, max = 255)) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = 0.2) + 
  geom_smooth(method = "lm", color = rgb(22, 160, 133, max = 255), size = 1, se = F) +
  theme_minimal() +
  labs(x = "Theoretical Quantiles",
       y = "RE Quantiles",
       title = "Normality of Random Effects",
       subtitle = "Day")

# ~ Farm

REQQ.farm <- result.mod$REQQ$Farm

reqq.plot.farm <- ggplot(REQQ.farm, aes(x = x, y = y)) +
  geom_point(size = 2, color = rgb(44, 62, 80, max = 255)) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = 0.2) + 
  geom_smooth(method = "lm", color = rgb(22, 160, 133, max = 255), size = 1, se = F) +
  theme_minimal() +
  labs(x = "Theoretical Quantiles",
       y = "RE Quantiles",
       title = "Normality of Random Effects",
       subtitle = "Farm")

#================================================
# Plot observed vs. fitted ----

figure.title3 <- paste0(mydir,"/Observed vs Fitted.png")

final.plot3 <- grid.arrange(obs.fit.day,
                            obs.fit.trt,
                            obs.fit.region,
                            obs.fit.farm, 
                            ncol = 2,
                            top = tableGrob(t(title.model),
                                            theme = ttheme_minimal(padding = unit(c(0,8),'mm'),
                                                                   base_colour = "black",
                                                                   base_size = 16)))

ggsave(figure.title3,
       grid.arrange(arrangeGrob(final.plot3,
                                top = textGrob(t(resp.variable),
                                               gp = gpar(fontsize = 18, fontface = "bold")))),
       width = 25, height = 27, units = "cm")

#================================================
# Plot residuals vs. fitted and random effects ----

figure.title4 <- paste0(mydir,"/Residuals V1.png")

final.plot4 <- grid.arrange(plot.norm.resid,
                            plot.qq.resid,
                            box.day,
                            box.trt,
                            box.region,
                            box.farm,
                            ncol = 2,
                            top = tableGrob(t(title.model),
                                            theme = ttheme_minimal(padding = unit(c(0,8),'mm'),
                                                                   base_colour = "black",
                                                                   base_size = 16)))

ggsave(figure.title4,
       grid.arrange(arrangeGrob(final.plot4,
                                top = textGrob(t(resp.variable),
                                               gp = gpar(fontsize = 18, fontface = "bold")))),
       width = 25, height = 32, units = "cm")

#================================================
# Plot residuals and collinearity ----

figure.title5 <- paste0(mydir,"/Residuals V2.png")

final.plot5 <- grid.arrange(plot.res.fit,
                            plot.binned,
                            reqq.plot.day,
                            reqq.plot.farm,
                            plot.coll,
                            ncol = 2,
                            top = tableGrob(t(title.model),
                                            theme = ttheme_minimal(padding = unit(c(0,8),'mm'),
                                                                   base_colour = "black",
                                                                   base_size = 16)))

ggsave(figure.title5,
       grid.arrange(arrangeGrob(final.plot5,
                                top = textGrob(t(resp.variable),
                                               gp = gpar(fontsize = 18, fontface = "bold")))),
       width = 25, height = 32, units = "cm")

#================================================
# Plot data - Model output ----
# Panels: Region ~ Farm

# Raw data

g1 <- ggplot(resilience_mod, 
             aes(x = Day, y = plot_meanC_ratio)) +
  geom_point(aes(fill = treatment, color = treatment),
             size = 2, alpha = 0.2) +
  facet_grid(Region ~ Farm) +
  geom_smooth(aes(y = Fitted, color = treatment),
              method = "lm", se = F) +
  theme_minimal() +
  theme(strip.background = element_rect(),
        panel.spacing = unit(1, "lines"),
        legend.title = element_text(face = "bold"),
        axis.title.x = element_text(size = 12, face = "bold", margin = margin(15,0,0,0)),
        axis.title.y = element_text(size = 12, face = "bold", margin = margin(0,15,0,0)),
        plot.title = element_text(size = 14, face = "bold")) +
  scale_fill_manual(values = c("blue","red")) +
  scale_color_manual(values = c("blue","red")) +
  scale_x_continuous(limits = c(0,64), breaks = c(0,8,16,32,64)) +
  labs(x = "Days since the end of the simulated drought",
       y = ylab,
       title = "Raw data",
       subtitle = "lm(fitted data ~ day)")

# Line plot

g2 <- ggplot(resilience_mod, 
             aes(x = Day, y = Fitted)) +
  facet_grid(Region ~ Farm) +
  geom_smooth(aes(color = treatment),
              method = "lm", se = F) +
  theme_minimal() +
  theme(strip.background = element_rect(),
        panel.spacing = unit(1, "lines"),
        legend.title = element_text(face = "bold"),
        axis.title.x = element_text(size = 12, face = "bold", margin = margin(15,0,0,0)),
        axis.title.y = element_text(size = 12, face = "bold", margin = margin(0,15,0,0)),
        plot.title = element_text(size = 14, face = "bold")) +
  scale_fill_manual(values = c("blue","red")) +
  scale_color_manual(values = c("blue","red")) +
  scale_x_continuous(limits = c(0,64), breaks = c(0,8,16,32,64)) +
  labs(x = "Days since the end of the simulated drought",
       title = "",
       subtitle = "lm(fitted data ~ day)")

## Panels: Region

# Raw data

g3 <- ggplot(resilience_mod, 
             aes(x = Day, y = plot_meanC_ratio)) +
  geom_point(aes(fill = treatment, color = treatment),
             size = 3, alpha = 0.2) +
  facet_wrap(~ Region) +
  geom_smooth(aes(y = Fitted, color = treatment, linetype = Farm),
              method = "lm", se = F, size = 0.6) +
  geom_smooth(aes(y = Fitted, color = treatment),
              method = "lm", se = F, size = 1) +
  theme_minimal() +
  theme(strip.background = element_rect(),
        panel.spacing = unit(1, "lines"),
        legend.title = element_text(face = "bold"),
        axis.title.x = element_text(size = 12, face = "bold", margin = margin(15,0,0,0)),
        axis.title.y = element_text(size = 12, face = "bold", margin = margin(0,15,0,0)),
        plot.title = element_text(size = 14, face = "bold")) +
  scale_fill_manual(values = c("blue","red")) +
  scale_color_manual(values = c("blue","red")) +
  scale_linetype_manual(values = c(2,3,4,5,6)) +
  scale_x_continuous(limits = c(0,64), breaks = c(0,8,16,32,64)) +
  labs(x = "Days since the end of the simulated drought",
       y = ylab,
       title = "Raw data",
       subtitle = "lm(fitted data ~ day)")

# Line plot

g4 <-  ggplot(resilience_mod, 
              aes(x = Day, y = Fitted)) +
  facet_wrap(~ Region) +
  geom_smooth(aes(color = treatment, linetype = Farm),
              method = "lm", se = F, size = 0.7) +
  geom_smooth(aes(color = treatment),
              method = "lm", se = F, size = 1) +
  theme_minimal() +
  theme(strip.background = element_rect(),
        panel.spacing = unit(1, "lines"),
        legend.title = element_text(face = "bold"),
        axis.title.x = element_text(size = 12, face = "bold", margin = margin(15,0,0,0)),
        axis.title.y = element_text(size = 12, face = "bold", margin = margin(0,15,0,0)),
        plot.title = element_text(size = 14, face = "bold")) +
  scale_fill_manual(values = c("blue","red")) +
  scale_color_manual(values = c("blue","red")) +
  scale_linetype_manual(values = c(2,3,4,5,6)) +
  scale_x_continuous(limits = c(0,64), breaks = c(0,8,16,32,64)) +
  labs(x = "Days since the end of the drought",
       title = "",
       subtitle = "lm(fitted data ~ day)")

# All four plots together

figure.title6 <- paste0(mydir,"/Model output.png")

final.plot6 <- grid.arrange(g1,g3,g2,g4,
                            ncol = 2,
                            top = tableGrob(t(title.model),
                                            theme = ttheme_minimal(padding = unit(c(0,8),'mm'),
                                                                   base_colour = "black",
                                                                   base_size = 16)))


ggsave(figure.title6,
       grid.arrange(arrangeGrob(final.plot6,
                                top = textGrob(t(resp.variable),
                                               gp = gpar(fontsize = 18, fontface = "bold")))),
       width = 40, height = 32, units = "cm")

# Only the last plot

figure.title7 <- paste0(mydir,"/Model output 2.png")

g4 <- g4 + labs(title = title.model)

ggsave(figure.title7, g4, width = 9, height = 7)

#================================================
# Statistics
 
AIC(lmer_full_mod)                                  ## -21.68974
model_performance(lmer_full_mod)$R2_marginal        ## 0.3259244
model_performance(lmer_full_mod)$R2_conditional     ## 0.3513399

# write.table(aov_mod, paste0(mydir.data, "/LMER Anova output - Soil moisture ratio vs Day, Trt and Region.csv"), 
#             sep = ",", row.names = F)
# 
# write.table(fixef_out, paste0(mydir.data, "/LMER Model output fixef - Soil moisture ratio vs Day, Trt and Region.csv"), 
#             sep = ",", row.names = F)
# 
# write.table(random_out.1, paste0(mydir.data, "/LMER Model output random Farm - Soil moisture ratio vs Day, Trt and Region.csv"), 
#             sep = ",", row.names = F)
# 
# write.table(random_out.2, paste0(mydir.data, "/LMER Model output random Day - Soil moisture ratio vs Day, Trt and Region.csv"), 
#             sep = ",", row.names = F)
