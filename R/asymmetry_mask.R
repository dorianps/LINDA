asymmetry_mask = function(img,
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
