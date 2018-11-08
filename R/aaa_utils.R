print_msg = function(msg, verbose = TRUE) {
  if (verbose) {
    msg = paste(format(Sys.time(), "\n%H:%M") , msg)
    cat(msg)
  }
}

stripRF <- function(rf) {
  rf$predicted <- NULL
  rf$oob.times <- NULL
  rf$y <- NULL
  rf$votes <- NULL
  rf$indexOut <- NULL
  rf$index    <- NULL
  rf$trainingData <- NULL

  attr(rf$terms,".Environment") <- c()
  attr(rf$formula,".Environment") <- c()

  rf
}
