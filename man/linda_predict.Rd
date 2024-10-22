% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/linda_predict_function.R
\name{linda_predict}
\alias{linda_predict}
\title{Run Lesion Prediction from LINDA}
\usage{
linda_predict(file = NA, brain_mask = NULL, n_skull_iter = 2,
  verbose = TRUE, outdir = NULL, voxel_resampling = c(2, 2, 2),
  sigma = 2, reflaxis = 0,
  saveMNI = file.exists(system.file("extdata", "pennTemplate",
  "templateToCh2_0GenericAffine.mat", package = "LINDA", mustWork =
  FALSE)), cache = TRUE)
}
\arguments{
\item{file}{Filename of T1 image}

\item{brain_mask}{A filename or \code{antsImage} object.
If this is passed in, then skull stripping is not done}

\item{n_skull_iter}{Number of skull stripping iterations}

\item{verbose}{Print diagnostic messages}

\item{outdir}{Output directory}

\item{voxel_resampling}{Resampling resolution of voxesl}

\item{sigma}{Smoothing factor, passed to
\code{\link{asymmetry_mask}} and
\code{\link{smoothImage}}}

\item{reflaxis}{Reflection axis}

\item{saveMNI}{(logical) whether to save outputs in MNI space
If transformation files are available, \code{saveMNI=TRUE}.
Otherwise \code{saveMNI=FALSE}. Manually setting to TRUE
without transformation files will force a de novo registration
between internal templates.}

\item{cache}{(default=TRUE) use existing processed files to
speed up processing. Useful for interrupted processes. Will
re-process and overwrite if set to FALSE}
}
\value{
A list of things
}
\description{
Run Lesion Prediction from LINDA
}
