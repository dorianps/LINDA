#' Asymmetry Mask
#'
#' @param img an \code{\link{antsImage}} of T1 image
#' @param brain_mask an \code{\link{antsImage}} of brain mask
#' @param reflaxis Reflection axis
#' @param sigma Smoothing sigma
#' @param verbose print diagnostic messages
#'
#' @return A list of the reflection and the mask
#' @export
#'
asymmetry_mask = function(
  img,
  brain_mask,
  reflaxis = 0,
  sigma = 2,
  verbose = TRUE) {
  # compute asymmetry mask
  print_msg("Computing asymmetry mask...", verbose = verbose)

  asymmetry = reflectImage(img, axis = reflaxis, tx = 'Affine')

  reflect = smoothImage(asymmetry$warpedmovout, sigma = sigma) -
    smoothImage(img, sigma = sigma)
  reflect[reflect < 0] = 0
  reflect = iMath(reflect, 'Normalize')
  mask = brain_mask - reflect
  mask = thresholdImage(mask, 0.6, Inf) * brain_mask

  L = list(reflection = asymmetry,
           mask = mask)
  return(L)
}
