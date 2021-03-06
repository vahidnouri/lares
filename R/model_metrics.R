####################################################################
#' Model Metrics and Performance
#' 
#' This function lets the user get a confusion matrix and accuracy, and 
#' for for binary classification models: AUC, Precision, Sensitivity, and
#' Specificity.
#' 
#' @family Machine Learning
#' @family Model metrics
#' @family Calculus
#' @param tag Vector. Real known label
#' @param score Vector. Predicted value or model's result
#' @param multis Data.frame. Containing columns with each category score 
#' (only used when more than 2 categories coexist)
#' @param abc Boolean. Arrange columns and rows alphabetically 
#' when categorical values?
#' @param thresh Integer. Threshold for selecting binary or regression 
#' models: this number is the threshold of unique values we should 
#' have in 'tag' (more than: regression; less than: classification)
#' @param thresh_cm Numeric. Value to splits the results for the 
#' confusion matrix. Range of values: (0-1)
#' @param target Value. Which is your target positive value? If 
#' set to 'auto', the target with largest mean(score) will be 
#' selected. Change the value to overwrite. Only used when binary
#' categorical model.
#' @param type Character. One of: "train", "test".
#' @param model_name Character. Model's name
#' @param plots Boolean. Include plots?
#' @param subtitle Character. Subtitle for plots
#' @examples 
#' data(dfr) # Results for AutoML Predictions
#' lapply(dfr, head)
#' 
#' # Metrics for Binomial Model
#' met1 <- model_metrics(dfr$class2$tag, dfr$class2$scores,
#'                       model_name = "Titanic Survived Model",
#'                       plots = FALSE)
#' print(met1)
#' 
#' # Metrics for Multi-Categorical Model
#' met2 <- model_metrics(dfr$class3$tag, dfr$class3$score,
#'                       multis = subset(dfr$class3, select = -c(tag, score)),
#'                       model_name = "Titanic Class Model",
#'                       plots = FALSE)
#' print(met2)
#'           
#' # Metrics for Regression Model
#' met3 <- model_metrics(dfr$regr$tag, dfr$regr$score,
#'                       model_name = "Titanic Fare Model",
#'                       plots = FALSE)
#' print(met3)
#' @export
model_metrics <- function(tag, score, multis = NA, 
                          abc = TRUE,
                          thresh = 10, 
                          thresh_cm = 0.5, 
                          target = "auto",
                          type = "test",
                          model_name = NA,
                          plots = TRUE, 
                          subtitle = NA){
  
  if (length(tag) != length(score))
    stop("tag and score have different lengths!")
  
  metrics <- list()
  cats <- sort(unique(as.character(tag)))
  model_type <- ifelse(length(cats) <= thresh, "Classifier", "Regression")    
  
  # When seems numeric but is categorical
  if (model_type == "Classifier" & sum(grepl('^[0-9]', cats)) > 0)
    tag <- as.factor(as.character(ifelse(
      grepl('^[0-9]', tag), paste0("n_", tag), as.character(tag))))
  # When is regression should always be numerical
  if (model_type == "Regression")
    tag <- as.numeric(tag)
  
  if (model_type == "Classifier") {
    
    dic <- c("AUC: Area Under the Curve",
             "ACC: Accuracy",
             "PRC: Precision = Positive Predictive Value",
             "TPR: Sensitivity = Recall = Hit rate = True Positive Rate",
             "TNR: Specificity = Selectivity = True Negative Rate",
             "Logloss (Error): Logarithmic loss [Neutral classification: 0.69315]",
             "Gain: When best n deciles selected, what % of the real target observations are picked?",
             "Lift: When best n deciles selected, how much better than random is?")
    metrics[["dictionary"]] <- dic
    
    tag <- as.character(tag)
    
    if (is.numeric(score)) {
      new <- data.frame(score = score) %>%
        mutate(new = ifelse(.data$score >= thresh_cm, cats[1], cats[2])) %>% .$new
    } else {
      new <- score
    }
    
    conf <- squareTable(tag, new)
    total <- sum(conf)
    trues <- sum(diag(conf))
    falses <- total - trues
    
    # For Binaries
    if (length(cats) == 2) {
      metrics[["confusion_matrix"]] <- conf
      ROC <- pROC::roc(tag, as.numeric(score), ci = TRUE, quiet = TRUE)
      nums <- data.frame(
        AUC = ROC$auc,
        ACC = trues / total,
        PRC = conf[2,2] / (conf[2,2] + conf[1,2]),
        TPR = conf[2,2] / (conf[2,2] + conf[2,1]),
        TNR = conf[1,1] / (conf[1,1] + conf[1,2]))
      metrics[["gain_lift"]] <- gain_lift(tag, score, target = target, quiet = FALSE)
      metrics[["metrics"]] <- signif(nums, 5)
    } else {
      
      # For Multi-Categories
      tags <- sort(unique(tag))
      if (is.na(multis)[1]) 
        stop("You have to input a data.frame with each tag's probability into the multis parameter.")
      if (!all(as.character(tags) %in% colnames(multis)))
        stop(paste0("Your multis data.frame colums should be ", vector2text(tags),
                    " (not ", vector2text(colnames(multis)), ")"))
      if (!all(colnames(multis) %in% as.character(tags))) {
        multis <- multis[,colnames(multis) %in% as.character(tags)]
      }
      
      df <- data.frame(tag, score)
      metrics[["confusion_matrix"]] <- conf_mat(tag, score)
      AUCs <- t(ROC(tag, score, multis)$ci)[,2]
      m <- data.frame(
        AUC = mean(AUCs[1:length(cats)], na.rm = TRUE),
        ACC = trues / total)
      metrics[["metrics"]] <- signif(m, 5)
      nums <- c()
      
      for (i in 1:length(cats)) {
        tagi <- ifelse(tag == cats[i], 1, 0)
        predi <- as.numeric(ifelse(score == cats[i], 1, 0))
        conf_mati <- squareTable(tagi, predi)
        if (nrow(data.frame(conf_mati)) == 4) {
          total <- sum(conf_mati)
          trues <- sum(diag(conf_mati))
          falses <- total - trues
          numsi <- data.frame(
            tag = cats[i],
            ACC = trues / total,
            PRC = conf_mati[2,2] / (conf_mati[2,2] + conf_mati[1,2]),
            TPR = conf_mati[2,2] / (conf_mati[2,2] + conf_mati[2,1]),
            TNR = conf_mati[1,1] / (conf_mati[1,1] + conf_mati[1,2]))
          nums <- rbind(nums, numsi) 
        }
      }
      nums$AUC <- AUCs[1:nrow(nums)]
      nums <- left_join(freqs(select(df, .data$tag), .data$tag), nums, "tag") %>% 
        select(.data$tag, .data$n, .data$p, .data$AUC, everything(), -.data$pcum)
      metrics[["metrics_tags"]] <- mutate_if(nums, is.numeric, list(~ signif(., 5)))
    }
    
    if (plots & type == "test") {
      plots <- list()
      # CUMULATIVE GAINS PLOT
      plots[["gains"]] <- mplot_gain(
        tag, score, multis, target = "auto", splits = 10, quiet = TRUE)
      # CUMULATIVE RESPONSE PLOT
      plots[["response"]] <- mplot_response(
        tag, score, multis, target = "auto", splits = 10, highlight = "auto", quiet = TRUE)
      # CONFUSION MATRIX PLOT
      plots[["conf_matrix"]] <- mplot_conf(
        tag, score, thresh_cm, abc = abc, subtitle = subtitle, model_name = model_name) 
      # ROC CURVES PLOT
      plots[["ROC"]] <- invisible(mplot_roc(
        tag, score, multis, subtitle = subtitle, model_name = model_name)) 
      # Bring them all!
      metrics[["plots"]] <- plots
    }
  }
  
  if (model_type == "Regression") {
    
    dic <- c("RMSE: Root Mean Squared Error",
             "MAE: Mean Average Error",
             "MAPE: Mean Absolute Percentage Error",
             "MSE: Mean Squared Error",
             "RSQ: R Squared",
             "RSQA: Adjusted R Squared")
    metrics[["dictionary"]] <- dic
    
    metrics[["metrics"]] <- errors(tag, score)
  }
  
  if (type == "train")
    metrics$dictionary <- NULL
  
  return(metrics)
}


####################################################################
#' Confussion Matrix
#' 
#' This function calculates a Confussion Matrix using crosstab for
#' 2 or more categories. You can either set the score and threshold
#' or the labels you wish to cross with.
#' 
#' You may use \code{mplot_conf()} or set \code{plot=TRUE}.
#' 
#' @family Machine Learning
#' @family Model metrics
#' @param tag Vector. Real known label
#' @param score Vector. Predicted value or model's result
#' @param thresh Numeric. Value which splits the results for the 
#' confusion matrix when binary.
#' @param sense Character. Inequation sense for threshhold: <, <=, >=, >
#' @param plot Boolean. Plot result? Uses \code{mplot_conf()}
#' @examples 
#' data(dfr) # Results for AutoML Predictions
#' lapply(dfr[c(1,2)], head)
#' 
#' # Results for Binomial Model
#' conf_mat(dfr$class2$tag, dfr$class2$scores)
#' conf_mat(dfr$class2$tag, dfr$class2$scores, thresh = 0.3)
#' conf_mat(dfr$class2$tag, dfr$class2$scores, sense = "<=")
#' 
#' # Results for Multi-Categorical Model
#' conf_mat(dfr$class3$tag, dfr$class3$score)
#' @export
conf_mat <- function(tag, score, thresh = 0.5, sense = ">=", plot = FALSE) {
  
  if (plot) 
    return(mplot_conf(tag, score, thresh = thresh))
  df <- data.frame(tag, score)
  
  # About tags
  labels <- df %>% 
    group_by(.data$tag, .drop = FALSE) %>% 
    tally(wt = NULL) %>% 
    arrange(desc(.data$n)) %>% 
    .$tag
  df <- df %>% mutate(tag = factor(.data$tag, levels = unique(.data$tag)))
  
  # About scores
  if (is.numeric(df$score) & length(unique(tag)) == 2) {
    check_opts(sense, c("<", "<=", ">=", ">"))
    s <- do.call(sense, list(df$score, thresh))
    df <- mutate(df, pred = ifelse(s, as.character(labels[1]), as.character(labels[2])))
  } else {
    df <- mutate(df, pred = .data$score)
  }
  
  # Confussion Matrix
  ret <- df %>% 
    rename("Real" = .data$tag, "Pred" = .data$pred) %>%
    crosstab(.data$Real, .data$Pred, total = FALSE)
  ret[is.na(ret)] <- 0
  
  return(as_tibble(ret))
}


####################################################################
#' Cumulative Gain, Lift and Response
#' 
#' This function calculates cumulative gain, lift, and response 
#' values for a predictive score of a specific target. You can use the 
#' \code{mplot_gain()} function to create a plot.
#' 
#' @family Machine Learning
#' @family Model metrics
#' @param tag Vector. Real known label
#' @param score Vector. Predicted value or model's result
#' @param target Value. Which is your target positive value? If 
#' set to 'auto', the target with largest mean(score) will be 
#' selected. Change the value to overwrite. Only used when binary
#' categorical model.
#' @param splits Integer. Numer of percentiles to split the data
#' @param plot Boolean. Plot results? Uses \code{mplot_gain()}
#' @param quiet Boolean. Do not show message for auto target?
#' @examples 
#' data(dfr) # Results for AutoML Predictions
#' head(dfr$class2)
#' 
#' # Results for Binomial Model
#' gain_lift(dfr$class2$tag, dfr$class2$scores, target = "FALSE")
#' gain_lift(dfr$class2$tag, dfr$class2$scores, target = "TRUE", splits = 5)
#' @export
gain_lift <- function(tag, score, target = "auto", splits = 10, 
                      plot = FALSE, quiet = FALSE) {
  
  if (splits <= 1) stop("You must set more than 1 split")
  aux <- target_set(tag, score, target, quiet)
  df <- aux$df
  which <- aux$which
  
  sc <- df %>% 
    mutate(tag = ifelse(.data$tag == which, TRUE, FALSE)) %>%
    arrange(desc(.data$score)) %>%
    mutate(percentile = .bincode(
      .data$score, quantile(.data$score, probs = seq(0, 1, length = splits + 1), 
                            include.lowest = TRUE), 
      right = TRUE, include.lowest = TRUE)) %>%
    mutate(percentile = rev(factor(.data$percentile, 1:splits)))
  
  wizard <- sc %>% 
    filter(.data$tag == TRUE) %>% 
    mutate(percentile = sc$percentile[1:length(sc$percentile[sc$tag == TRUE])]) %>%
    group_by(.data$percentile) %>% tally() %>% 
    ungroup() %>% mutate(p = 100 * .data$n/sum(.data$n), pcum = cumsum(.data$p)) %>% 
    select(.data$percentile, .data$pcum) %>% 
    rename(optimal = .data$pcum)
  
  gains <- sc %>% 
    group_by(.data$percentile) %>% 
    summarise(total = n(), target = sum(.data$tag), score = 100 * min(.data$score)) %>%
    left_join(wizard, "percentile") %>% 
    replace(is.na(.), 100) %>% ungroup() %>%
    mutate(gain = 100 * cumsum(.data$target)/sum(.data$target),
           random = 100 * cumsum(.data$total)/sum(.data$total),
           lift = 100 * (.data$gain/.data$random - 1),
           response = 100 * .data$target/sum(.data$target),
           value = which) %>%
    select(.data$percentile, .data$value, .data$random, .data$target, .data$total, 
           .data$gain, .data$optimal, .data$lift, .data$response, .data$score)
  
  if (plot) {
    plots <- list()
    plots[["gain"]] <- mplot_gain(
      tag, score, target = which, splits = splits)
    plots[["response"]] <- mplot_response(
      tag, score, target = which, splits = splits)
    return(plots) 
  }
  return(gains)
  
}


####################################################################
#' AUC and ROC Curves Data
#' 
#' This function calculates ROC Curves and AUC values with 95\% confidence 
#' range. It also works for multi-categorical models.
#' 
#' @section Plot Results:
#' To plot results, use the \code{mplot_roc()} function.
#' 
#' @family Machine Learning
#' @family Model metrics
#' @param tag Vector. Real known label
#' @param score Vector. Predicted value or model's result
#' @param multis Data.frame. Containing columns with each category score 
#' (only used when more than 2 categories coexist)
#' @examples 
#' data(dfr) # Results for AutoML Predictions
#' lapply(dfr[c(1,2)], head)
#' 
#' # ROC Data for Binomial Model
#' roc1 <- ROC(dfr$class2$tag, dfr$class2$scores)
#' lapply(roc1, head)
#' 
#' # ROC Data for Multi-Categorical Model
#' roc2 <- ROC(dfr$class3$tag, dfr$class3$score,
#'             multis = subset(dfr$class3, select = -c(tag, score)))
#' lapply(roc2, head)
#' @export
ROC <- function(tag, score, multis = NA) {
  
  if (length(tag) != length(score)) {
    message("The tag and score vectors should be the same length.")
    stop(message(paste("Currently, tag has",length(tag),"rows and score has",length(score))))
  }
  
  if (!is.numeric(score) & is.na(multis)[1]) {
    score <- as.numeric(score) 
    warning("You should use the multis parameter to add each category's score")
  }
  
  if (length(unique(tag)) <= 1) {
    tag[1] <- "dummy_label"
    warning("Only 1 unique label detected. Adding single noice observation.")
  }
  
  if (is.na(multis)[1]) {
    roc <- pROC::roc(tag, score, ci = TRUE, quiet = TRUE)
    coords <- data.frame(
      fpr = rev(roc$specificities),
      tpr = rev(roc$sensitivities)) %>%
      mutate(label = "2cats")
    ci <- data.frame(roc$ci, row.names = c("min","AUC","max"))
  } else {
    df <- data.frame(tag = tag, score = score, multis)
    cols <- colnames(df)
    coords <- c()
    rocs <- list()
    for (i in 1:(length(cols) - 2)) {
      which <- colnames(df)[2 + i]
      res <- df[,c(which)]
      label <- ifelse(df[,1] == which, which, "other")
      if (length(unique(label)) <= 1) {
        label[1] <- "dummy_label"
        warning("Only 1 unique label detected. Adding single noice observation.")
      }
      roci <- pROC::roc(label, res, ci = TRUE, quiet = TRUE)
      rocs[[paste(cols[i + 2])]] <- roci
      iter <- data.frame(fpr = rev(roci$specificities),
                         tpr = rev(roci$sensitivities),
                         label = paste(round(100*roci$auc,2), which, sep = "% | "))
      coords <- rbind(coords, iter)
    }
    ci <- data.frame(lapply(rocs, "[[", "ci")) %>% mutate(mean = rowMeans(.))
    row.names(ci) <- c("min","AUC","max")
  }
  ret <- list(ci = ci, roc = coords)
  if (!is.na(multis)[1]) {
    ret[["rocs"]] <- rocs  
  }
  return(ret)
}



####################################################################
#' Calculate Continuous Values Errors
#' 
#' This function lets the user calculate all errors and R squared 
#' simultaneously.
#' 
#' @family Model metrics
#' @param tag Vector. Real known label
#' @param score Vector. Predicted value or model's result
#' @examples 
#' data(dfr) # Results for AutoML Predictions
#' head(dfr$regr)
#' df <- errors(dfr$regr$tag, dfr$regr$score)
#' head(df)
#' @export
errors <- function(tag, score){ 
  data.frame(
    rmse = rmse(tag, score),
    mae = mae(tag, score),
    mape = mape(tag, score),
    mse = mse(tag, score),
    rsq = rsq(tag, score),
    rsqa = rsqa(tag, score)
  )
}

####################################################################
#' Root Mean Squared Error (RMSE)
#' 
#' This function lets the user calculate Root Mean Squared Error
#' 
#' @param tag Vector. Real known label
#' @param score Vector. Predicted value or model's result
#' @export
#' @rdname errors
rmse <- function(tag, score){
  error <- tag - score
  sqrt(mean(error^2))
}


####################################################################
#' Mean Absolute Error (MAE)
#' 
#' This function lets the user calculate Mean Absolute Error
#' 
#' @param tag Vector. Real known label
#' @param score Vector. Predicted value or model's result
#' @export
#' @rdname errors
mae <- function(tag, score){
  error <- tag - score
  mean(abs(error))
}


####################################################################
#' Mean Squared Error (MSE)
#' 
#' This function lets the user calculate Mean Squared Error
#' 
#' @param tag Vector. Real known label
#' @param score Vector. Predicted value or model's result
#' @export
#' @rdname errors
mse <- function(tag, score){ 
  error <- tag - score
  mean(error^2)
}


####################################################################
#' Mean Absolute Percentage Error (MAPE)
#' 
#' This function lets the user calculate Mean Squared Error
#' 
#' @param tag Vector. Real known label
#' @param score Vector. Predicted value or model's result
#' @export
#' @rdname errors
mape <- function(tag, score){ 
  error <- (tag - score) / tag
  error <- error[!is.infinite(error)]
  tag <- tag[tag != 0]
  mean(abs(error/tag))
}


####################################################################
#' R Squared
#' 
#' This function lets the user calculate R Squared
#' 
#' @param tag Vector. Real known label
#' @param score Vector. Predicted value or model's result
#' @export
#' @rdname errors
rsq <- function(tag, score){ 
  fit <- lm(score ~ tag)
  signif(summary(fit)$r.squared, 4)
}

####################################################################
#' Adjusted R Squared
#' 
#' This function lets the user calculate Adjusted R Squared
#' 
#' @param tag Vector. Real known label
#' @param score Vector. Predicted value or model's result
#' @export
#' @rdname errors
rsqa <- function(tag, score){ 
  fit <- lm(score ~ tag)
  signif(summary(fit)$adj.r.squared, 4)
}


####################################################################
#' Loggarithmic Loss Function for Binary Models
#'
#' This function calculates log loss/cross-entropy loss for binary 
#' models. NOTE: when result is 0.69315, the classification is neutral; 
#' it assigns equal probability to both classes.
#'
#' @family Model metrics
#' @param tag Vector. Real known label
#' @param score Vector. Predicted value or model's result
#' @param eps Numeric. Epsilon value
#' @export
loglossBinary <- function(tag, score, eps = 0.001) {
  
  if (length(unique(tag)) != 2)
    stop("Your 'tag' vector is not binary!")
  
  if (length(tag) != length(score)) {
    message("The tag and score vectors should be the same length.")
    stop(message(paste("Currently, tag has", length(tag),
                       "rows and score has", length(score)))
    )
  }
  
  if (!is.numeric(tag)) tag <- as.integer(tag) - 1
  
  score <- pmax(pmin(score, 1 - eps), eps)
  output <- -mean(tag * log(score) + (1 - tag) * log(1 - score))
  
  return(output)
  
}

squareTable <- function(x, y) {
  x <- factor(x)
  y <- factor(y)
  commonLevels <- sort(unique(c(levels(x), levels(y))))
  Real <- factor(x, levels = commonLevels)
  Pred <- factor(y, levels = commonLevels)
  table(Real, Pred)
}
