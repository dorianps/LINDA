#' @importFrom ANTsRCore kmeansSegmentation
getLesionFeatures = function(
  img, template, bmask,
  sigma = 2,
  verbose = TRUE) {

  # fix TruncateIntensity incompatibility with old ANTsR binaries
  ops = iMath(20, 'GetOperations')
  ops = grepl('TruncateIntensity', ops)
  truncate =  ifelse(any(ops), 'TruncateIntensity', 'TruncateImageIntensity')



  # function to compute features for MRV-NRF
  if (any(dim(img) != dim(template))) {
    stop(paste(
      'Image - template dimension mismatch',
      paste(dim(img), collapse = 'x'),
      'vs.',
      paste(dim(template), collapse = 'x')
    ))
  }

  # # #  START FILLING FEATURES
  feats = list()

  # FEAT 1: kmean difference from controls
  con_avg_file = system.file("extdata", "sumkmean.nii.gz",
                             package = "LINDA",
                             mustWork = TRUE)
  conavg = antsImageRead(con_avg_file)
  kmeans_args = list(    img, k = 3,
                         kmask = bmask,
                         verbose = verbose)
  if (!"verbose" %in% formalArgs(kmeansSegmentation)) {
    kmeans_args$verbose = NULL
  }
  kmean = do.call(kmeansSegmentation, args = kmeans_args)
  kmean = kmean$segmentation
  # kmean = kmeansSegmentation(
  #   img, k = 3,
  #   kmask = bmask,
  #   verbose = verbose)$segmentation
  feats[[1]] = (conavg - kmean) %>% iMath('Normalize')
  # FEAT 2: gradient magnitude
  feats[[2]] = img %>% iMath('Grad') %>% iMath('Normalize')

  n4_con_avg_file = system.file("extdata", "N4ControlAvgerage.nii.gz",
                                package = "LINDA",
                                mustWork = TRUE)

  # FEAT 3: t1 difference from controls
  conavg = antsImageRead(n4_con_avg_file)
  temp = img %>% smoothImage(sigma = sigma) %>%
    iMath(truncate, 0.001, 0.999) %>%
    iMath('Normalize')

  feats[[3]] = (conavg - temp) %>%
    iMath(truncate, 0.01, 0.99) %>%
    iMath('Normalize')


  # FEAT 4: kmean
  feats[[4]] = antsImageClone(kmean)

  ref_con_avg_file = system.file("extdata",
                                 "ControlAverageReflected.nii.gz",
                                 package = "LINDA",
                                 mustWork = TRUE)

  # FEAT 5: reflection difference from controls
  conavg = antsImageRead(ref_con_avg_file)
  reflimg = reflectImage(img, axis = 1, tx = 'Affine')
  temp = iMath(reflimg$warpedmovout - img, truncate, 0.01, 0.99) %>% iMath('Normalize')
  feats[[5]] = (temp - conavg) %>% iMath('Normalize')

  # FEAT 6: t1 itself
  feats[[6]] = antsImageClone(img)   # iMath(img,'Normalize')

  names(feats) = c("d_controls", "d_controls_grad_mag",
                  "n4_d_controls", "kmean", "ref_diff",
                  "t1")
  return(feats)
}
