asymmetry_mask = function(img,
                          reflaxis = 0,
                          verbose = TRUE) {
  # compute asymmetry mask
  print_msg("Computing asymmetry mask...", verbose = verbose)


  asymmetry = reflectImage(img, axis = reflaxis, tx = 'Affine')

  reflect = smoothImage(asymmetry$warpedmovout, 2) - smoothImage(simg, 2)
  reflect[reflect < 0] = 0
  reflect = iMath(reflect, 'Normalize')
  mask.lesion1 = submask - reflect
  mask.lesion1 = thresholdImage(mask.lesion1, 0.6, Inf) * submask

  L = list(reflection = asymmetry,
           mask = mask.lesion1)
  return(L)
}
