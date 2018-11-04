#' Run Lesion Prediction from LINDA
#'
#' @param file Filename of T1 image
#' @param n_skull_iter Number of skull stripping iterations
#' @param verbose Print diagnostic messages
#' @param outdir Output directory
#' @param voxel_resampling Resampling resolution of voxesl
#' @param reflaxis Reflection axis
#' @param sigma Smoothing factor, passed to
#' \code{\link{asymmetry_mask}} and
#' \code{\link{smoothImage}}
#' @param cache Should files be just read in if they already exist?
#'
#' @return A list of things
#' @export
#'
#' @importFrom ANTsRCore iMath antsImageRead antsImageWrite antsRegistration
#' @importFrom ANTsRCore resampleImage smoothImage thresholdImage antsImageClone
#' @importFrom ANTsRCore antsApplyTransforms is.antsImage
#' @importFrom ANTsR abpN4 abpBrainExtraction reflectImage
#' @importFrom ANTsR composeTransformsToField
#' @importFrom magrittr %>%
linda_predict = function(
  file,
  n_skull_iter = 2,
  verbose = TRUE,
  outdir = NULL,
  voxel_resampling = c(2, 2, 2),
  sigma = 2,
  reflaxis = 0,
  cache = TRUE) {

  stopifnot(is.character(file))

  # create linda folder
  if (is.null(outdir)) {
    outdir = file.path(dirname(file), "linda")
  }
  print_msg(paste(
    'Creating folder:',
    outdir), verbose = verbose)
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

  template = system.file(
    "extdata", "pennTemplate", "template.nii.gz",
    package = "LINDA",
    mustWork = TRUE)
  template_brain = system.file(
    "extdata", "pennTemplate", "templateBrain.nii.gz",
    package = "LINDA",
    mustWork = TRUE)
  template_mask = system.file(
    "extdata", "pennTemplate", "templateBrainMask.nii.gz",
    package = "LINDA",
    mustWork = TRUE)

  ss_files = c(
    n4 = file.path(outdir, 'N4corrected.nii.gz'),
    brain_mask = file.path(outdir, 'BrainMask.nii.gz'),
    n4_brain = file.path(outdir, 'N4corrected_Brain.nii.gz')
  )
  if (all(file.exists(ss_files)) & cache) {
    ss = lapply(ss_files, antsImageRead)
    n4 = ss$n4
    submask = ss$brain_mask
    simg = ss$n4_brain
  } else {
    ss = n4_skull_strip(
      file = file,
      n_iter = n_skull_iter,
      template = template,
      template_brain = template_brain,
      template_mask = template_mask,
      verbose = verbose)
    n4 = ss$n4
    submask = ss$brain_mask
    simg = ss$n4_brain

    print_msg("Saving skull stripped files", verbose = verbose)

    antsImageWrite(n4, ss_files["n4"])
    antsImageWrite(submask, ss_files["brain_mask"])
    antsImageWrite(simg, ss_files["n4_brain"])
  }

  temp = antsImageRead(template)
  tempbrain = antsImageRead(template_brain)
  tempmask = antsImageRead(template_mask)

  # load other functions
  print_msg("Loading LINDA model", verbose = verbose)

  outfiles = c(
    flipped = file.path(outdir, 'N4corrected_Brain_LRflipped.nii.gz'),
    lesion_mask = file.path(outdir, 'Mask.lesion1_asym.nii.gz')
  )

  if (all(file.exists(outfiles)) & cache) {
    asymmetry = lapply(outfiles, antsImageRead)
    mask.lesion1 = asymmetry$lesion_mask
  } else {
    # compute asymmetry mask
    asymmetry = asymmetry_mask(
      img = simg,
      brain_mask = submask,
      reflaxis = reflaxis,
      sigma = sigma,
      verbose = verbose)
    mask.lesion1 = asymmetry$mask
    asymmetry = asymmetry$reflection

    antsImageWrite(
      asymmetry$warpedmovout,
      outfiles["flipped"]
    )

    print_msg("Saving asymmetry mask...", verbose = verbose)
    antsImageWrite(mask.lesion1,
                   outfiles["lesion_mask"])
  }

  outfiles = c(
    prediction = file.path(outdir,
                           'Prediction1.nii.gz'),
    lesion_mask = file.path(outdir, 'Mask.lesion2.nii.gz')
  )

  if (all(file.exists(outfiles)) & cache) {
    out1 = lapply(outfiles, antsImageRead)
    mask.lesion2 = out1$lesion_mask
    prediction = out1$prediction
  } else {
    out1 = run_prediction(
      img = simg,
      brain_mask = submask,
      template_mask = tempmask,
      voxel_resampling = voxel_resampling,
      template_brain = tempbrain,
      typeofTransform = "SyN",
      lesion_mask = mask.lesion1,
      reflaxis = reflaxis,
      sigma = sigma,
      verbose = verbose)
    prediction = out1$prediction
    print_msg("Saving prediction...", verbose = verbose)
    antsImageWrite(prediction, outfiles["prediction"])

    mask.lesion2 = out1$lesion_mask

    antsImageWrite(mask.lesion2,
                   outfiles["lesion_mask"])
  }


  outfiles = c(
    prediction = file.path(outdir,
                           'Prediction2.nii.gz'),
    lesion_mask = file.path(outdir, 'Mask.lesion3.nii.gz')
  )

  if (all(file.exists(outfiles)) & cache) {
    out2 = lapply(outfiles, antsImageRead)
    mask.lesion3 = out2$lesion_mask
    prediction2 = out2$prediction
  } else {

    out2 = run_prediction(
      img = simg,
      brain_mask = submask,
      template_mask = tempmask,
      voxel_resampling = voxel_resampling,
      template_brain = tempbrain,
      typeofTransform = "SyN",
      lesion_mask = mask.lesion2,
      reflaxis = reflaxis,
      sigma = sigma,
      verbose = verbose)

    prediction2 = out2$prediction
    antsImageWrite(prediction2, outfiles["prediction"])

    mask.lesion3 = out2$lesion_mask

    antsImageWrite(mask.lesion3, outfiles["lesion_mask"])
  }


  outfiles = c(
    prediction = file.path(outdir,
                           'Prediction2.nii.gz'),
    lesion_mask = file.path(outdir, 'Mask.lesion4.nii.gz')
  )

  # if (all(file.exists(outfiles)) & cache) {
  #   out3 = lapply(outfiles, antsImageRead)
  #   mask.lesion4 = out3$lesion_mask
  #   prediction3 = out3$prediction
  # } else {

  out3 = run_prediction(
    img = simg,
    brain_mask = submask,
    template_mask = tempmask,
    voxel_resampling = voxel_resampling,
    template_brain = tempbrain,
    typeofTransform = "SyN",
    lesion_mask = mask.lesion3,
    reflaxis = reflaxis,
    sigma = sigma,
    verbose = verbose)

  prediction3 = out3$prediction
  antsImageWrite(prediction3, outfiles["prediction"])

  mask.lesion4 = out3$lesion_mask

  antsImageWrite(mask.lesion4, outfiles["lesion_mask"])

  reg3 = out3$registration
  antsImageWrite(
    reg3$warpedfixout,
    file.path(outdir, 'Reg3_registered_to_template.nii.gz')
  )
  file.copy(
    reg3$fwdtransforms[1],
    file.path(outdir, 'Reg3_template_to_sub_warp.nii.gz')
  )
  file.copy(reg3$fwdtransforms[2],
            file.path(outdir , 'Reg3_template_to_sub_affine.mat'))
  file.copy(reg3$invtransforms[1],
            file.path(outdir , 'Reg3_sub_to_template_affine.mat'))
  file.copy(
    reg3$invtransforms[2],
    file.path(outdir , 'Reg3_sub_to_template_warp.nii.gz')
  )

  seg = out3$segmentation

  antsImageWrite(seg, file.path(outdir, 'Prediction3_template.nii.gz'))

  print_msg("Saving 3rd final prediction in native space...",
            verbose = verbose)
  segnative = out3$segmentation_native

  antsImageWrite(segnative,
                 file.path(outdir, 'Prediction3_native.nii.gz'))

  graded_map = out3$multi_res_seg$probs[[1]][[4]]

  # save graded map
  probles = resampleImage(graded_map,
                          dim(tempbrain),
                          useVoxels = 1,
                          interpType = 0)
  problesnative = antsApplyTransforms(
    fixed = simg,
    moving = probles,
    transformlist = reg3$fwdtransforms,
    interpolator = 'Linear',
    verbose = verbose > 1
  )
  print_msg("Saving probabilistic prediction in template space...",
            verbose = verbose)
  antsImageWrite(probles,
                 file.path(outdir,
                           'Prediction3_probability_template.nii.gz'))

  print_msg("Saving probabilistic prediction in native space...",
            verbose = verbose)
  antsImageWrite(problesnative,
                 file.path(outdir,
                           'Prediction3_probability_native.nii.gz'))



  # save in MNI coordinates
  print_msg("Transferring data in MNI (ch2) space...",
            verbose = verbose)

  warppenn = file.path(outdir, 'Reg3_sub_to_template_warp.nii.gz')
  affpenn = file.path(outdir, 'Reg3_sub_to_template_affine.mat')


  mni = system.file("extdata", "pennTemplate", "ch2.nii.gz",
                    package = "LINDA",
                    mustWork = TRUE)

  mni = antsImageRead(mni)

  print_msg("Transferring data in MNI (ch2) space...",
            verbose = verbose)



  warpmni = system.file("extdata", "pennTemplate",
                        "templateToCh2_1Warp.nii.gz",
                        package = "LINDA",
                        mustWork = FALSE)

  affmni = system.file("extdata",
                       "pennTemplate",
                       "templateToCh2_0GenericAffine.mat",
                       package = "LINDA",
                       mustWork = FALSE)

  if (!all(file.exists(warpmni, affmni))) {
    print_msg(paste0("Registering Template to MNI (ch2) space" ,
                     " (not subject specific)..."),
              verbose = verbose)
    temp_to_ch2 = antsRegistration(
      fixed = mni, moving = temp,
      typeofTransform = "SyN",
      verbose = verbose > 1)
    matrices = c(temp_to_ch2$fwdtransforms, affpenn, warppenn)
  } else {
    matrices = c(warpmni, affmni, affpenn, warppenn)
  }

  submni = antsApplyTransforms(
    moving = simg,
    fixed = mni,
    transformlist = matrices,
    interpolator = 'Linear',
    whichtoinvert = c(0, 0, 1, 0),
    verbose = verbose > 1
  )
  lesmni = antsApplyTransforms(
    moving = segnative,
    fixed = mni,
    transformlist = matrices,
    interpolator = 'NearestNeighbor',
    whichtoinvert = c(0, 0, 1, 0),
    verbose = verbose > 1
  )

  print_msg("Saving subject in MNI (ch2) space...",
            verbose = verbose)
  antsImageWrite(submni, file.path(outdir, 'Subject_in_MNI.nii.gz'))

  print_msg("Saving lesion in MNI (ch2) space...",
            verbose = verbose)
  antsImageWrite(lesmni, file.path(outdir, 'Lesion_in_MNI.nii.gz'))
  return(lesmni)

}
