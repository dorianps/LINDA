% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/asymmetry_mask.R
\name{asymmetry_mask}
\alias{asymmetry_mask}
\title{Asymmetry Mask}
\usage{
asymmetry_mask(img, brain_mask, reflaxis = 0, sigma = 2,
  verbose = TRUE)
}
\arguments{
\item{img}{an \code{antsImage} of T1 image}

\item{brain_mask}{an \code{antsImage} of brain mask}

\item{reflaxis}{Reflection axis}

\item{sigma}{Smoothing sigma}

\item{verbose}{print diagnostic messages}
}
\value{
A list of the reflection and the mask
}
\description{
Asymmetry Mask
}
