#' Run LINDA Iteration Prediction
#'
#' @param img image of T1
#' @param brain_mask image of brain mask
#' @param verbose Print diagnostic messages
#' @param template_brain image of template brain
#' @param template_mask image of template brain mask
#' @param typeofTransform type of transformation to perform
#' @param lesion_mask image of lesion mask from previous iteration
#' @param reflaxis Reflection axis
#' @param voxel_resampling Resampling resolution of voxesl
#' @param sigma Smoothing factor, passed to
#' \code{\link{asymmetry_mask}} and
#' \code{\link{smoothImage}}
#'
#' @return A list of stuff
#' @export
#'
run_prediction = function(
  img,
  brain_mask,
  template_brain,
  template_mask,
  typeofTransform = "SyN",
  lesion_mask,
  reflaxis = 0,
  voxel_resampling = c(2,2,2),
  sigma = 2,
  verbose = TRUE) {

  # half brain mask
  brainmask = iMath(template_mask, 'MD', 1)
  emptyimg = brainmask * 1
  emptyimg = as.array(emptyimg)
  emptyimg[1:91 , , ] = 0
  template_half_mask = resampleImage(
    brainmask * emptyimg,
    voxel_resampling,
    0,
    1)
  rm(emptyimg)

  # fix TruncateIntensity incompatibility with old ANTsR binaries
  ops = iMath(20, 'GetOperations')
  ops = grepl('TruncateIntensity', ops)
  truncate =  ifelse(any(ops), 'TruncateIntensity', 'TruncateImageIntensity')


  print_msg(paste("    Running registration:", typeofTransform), verbose = verbose)
  reg = antsRegistration(
    fixed = img,
    moving = template_brain,
    typeofTransform = typeofTransform,
    mask = lesion_mask,
    verbose = verbose > 1
  )
  reg$warpedfixout = reg$warpedfixout %>%
    iMath(truncate, 0.01, 0.99) %>%
    iMath('Normalize')
  tempmask = antsApplyTransforms(
    moving = brain_mask,
    fixed = template_brain,
    transformlist = reg$invtransforms,
    interpolator = 'NearestNeighbor',
    verbose = verbose > 1
  )

  # prepare features
  print_msg("    Feature calculation ", verbose = verbose)
  features = getLesionFeatures(
    reg$warpedfixout,
    template_brain,
    tempmask,
    sigma = sigma,
    verbose = verbose > 1)
  for (i in 1:length(features)) {
    features[[i]] = resampleImage(
      features[[i]],
      voxel_resampling,
      useVoxels = 0,
      interpType = 0) * template_half_mask
    # features[[i]] = resampleImageToTarget(
    #   image = features[[i]],
    #   target = template_half_mask,
    #   interpType = "nearestNeighbor") * template_half_mask
  }

  # 1st prediction
  print_msg("    Lesion segmentation", verbose = verbose)

  predlabel.sub = template_half_mask * 1
  predlabel.sub[features[[4]] == 0] = 0

  rad = c(1,1,1)
  mr = c(3, 2, 1)

  rflist = list(LINDA::rf_model1,
                LINDA::rf_model2,
                LINDA::rf_model3)


  mmseg <- suppressMessages(
    # ANTsR::mrvnrfs.predict(
    linda_mrvnrfs.predict_chunks(
      rflist,
      list(features),
      # features,
      predlabel.sub,
      rad = rad,
      multiResSchedule = mr,
      voxchunk = 5000
    )
  )
  prediction = mmseg$seg[[1]]
  # backproject
  print_msg("Backprojecting prediction...", verbose = verbose)
  seg = resampleImage(prediction,
                      dim(template_brain),
                      useVoxels = 1,
                      interpType = 1)
  # seg = resampleImageToTarget(
  #   image = prediction,
  #   target = template_brain,
  #   interpType = "nearestNeighbor")

  seg[seg != 4] = 0
  seg[seg == 4] = 1
  segnative = antsApplyTransforms(
    fixed = img,
    moving = seg,
    transformlist = reg$fwdtransforms,
    interpolator = 'NearestNeighbor',
    verbose = FALSE
  )
  mask.lesion2 = brain_mask * 1
  mask.lesion2[segnative == 1] = 0

  L = list(registration = reg,
           segmentation = seg,
           segmentation_native = segnative,
           prediction = prediction,
           lesion_mask = mask.lesion2,
           multi_res_seg = mmseg)
  return(L)
}


