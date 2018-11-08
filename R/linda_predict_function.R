#' Run Lesion Prediction from LINDA
#'
#' @param file Filename of T1 image
#' @param brain_mask A filename or \code{antsImage} object.
#' If this is passed in, then skull stripping is not done
#' @param n_skull_iter Number of skull stripping iterations
#' @param verbose Print diagnostic messages
#' @param outdir Output directory
#' @param voxel_resampling Resampling resolution of voxesl
#' @param reflaxis Reflection axis
#' @param sigma Smoothing factor, passed to
#' \code{\link{asymmetry_mask}} and
#' \code{\link{smoothImage}}
#' @param noMNI (default=FALSE) whether to avoid bringing data
#' into MNI space
#' @param cache (default=TRUE) use existing processed files to
#' speed up processing. Useful for interrupted processes. Will
#' re-process and overwrite if set to FALSE
#'
#' @return A list of things
#' @export
#'
#' @importFrom ANTsRCore iMath antsImageRead antsImageWrite antsRegistration
#' @importFrom ANTsRCore resampleImage smoothImage thresholdImage antsImageClone
#' @importFrom ANTsRCore antsApplyTransforms is.antsImage resampleImageToTarget
#' @importFrom ANTsR abpN4 abpBrainExtraction reflectImage
#' @importFrom ANTsR composeTransformsToField splitMask
#' @importFrom magrittr %>%
linda_predict = function(
  file=NA,
  brain_mask = NULL,
  n_skull_iter = 2,
  verbose = TRUE,
  outdir = NULL,
  voxel_resampling = c(2, 2, 2),
  sigma = 2,
  reflaxis = 0,
  noMNI = FALSE,
  cache = TRUE) {

  toc=Sys.time()

  # start capturing window output to save later
  outputLog = capture.output({

  print_msg(paste0('Starting LINDA v', packageVersion('LINDA')), verbose=verbose)

  if (is.na(file)) { # user did not specify a file, open chooser
    file = file.choose()
  } else { # user specified the file
    if ( !file.exists(file) ) stop(paste( 'File inexistent:', file ))
  }

  # create linda folder
  if (is.null(outdir)) {
    outdir = file.path(dirname(file), "linda")
  }

  if (!dir.exists(outdir)) {
    print_msg(paste(
      'Creating folder:', outdir), verbose = verbose)
    dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  } else {
    print_msg(paste(
      'Using existing folder:', outdir), verbose = verbose)
  }

  # if folder has already the final native output, stop processing
  segnative_file = file.path(outdir, 'Prediction3_native.nii.gz')
  if (file.exists(segnative_file) & cache) {
    print_msg('\nLINDA segmentation already present in folder.\n   Use "cache=FALSE" to reprocess and overwrite.',
              verbose=verbose)
    return(NULL)
  }



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

  reader = function(x) {
    if (!is.antsImage(x)) {
      y = antsImageRead(x)
    } else {
      y = antsImageClone(x)
    }
    return(y)
  }

  if (is.null(brain_mask)) {
    ss_files = c(
      n4 = file.path(outdir, 'N4corrected.nii.gz'),
      brain_mask = file.path(outdir, 'BrainMask.nii.gz'),
      n4_brain = file.path(outdir, 'N4corrected_Brain.nii.gz')
    )
    L = as.list(ss_files)
    if (all(file.exists(ss_files)) & cache) {
      print_msg('Found existing skull stripped files, loading ...', verbose = verbose)
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

      print_msg("Saving skull stripped files...", verbose = verbose)

      antsImageWrite(n4, ss_files["n4"])
      antsImageWrite(submask, ss_files["brain_mask"])
      antsImageWrite(simg, ss_files["n4_brain"])
    }
  } else {
    print_msg('Brain mask provided by user, using to skull strip ...', verbose = verbose)

    brain_mask = reader(brain_mask)
    brain_mask_file = file.path(outdir, 'BrainMask.nii.gz')
    antsImageWrite(brain_mask, brain_mask_file)
    L = list(brain_mask = brain_mask_file)

    simg = reader(file)
    submask = brain_mask
    simg = simg * submask
  }

  temp = antsImageRead(template)
  tempbrain = antsImageRead(template_brain)
  tempmask = antsImageRead(template_mask)

  # load other functions
  # print_msg("Loading LINDA model...", verbose = verbose)

  outfiles = c(
    flipped = file.path(outdir, 'N4corrected_Brain_LRflipped.nii.gz'),
    lesion_mask = file.path(outdir, 'Mask.lesion1_asym.nii.gz')
  )
  L = c(L, as.list(outfiles))

  if (all(file.exists(outfiles)) & cache) {
    print_msg('Found existing asymmetry mask, loading...', verbose = verbose)

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
  o = as.list(outfiles)
  names(o) = paste0(names(o), "_1")
  L = c(L, as.list(o))


  if (all(file.exists(outfiles)) & cache) {
    print_msg('Found existing mask from 1st prediction, loading ...', verbose = verbose)

    out1 = lapply(outfiles, antsImageRead)
    mask.lesion2 = out1$lesion_mask
    prediction = out1$prediction
  } else {

    print_msg('1st round of prediction...', verbose=verbose)

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
  o = as.list(outfiles)
  names(o) = paste0(names(o), "_2")
  L = c(L, as.list(o))

  if (all(file.exists(outfiles)) & cache) {
    print_msg('Found existing mask from 2nd prediction, loading ...', verbose = verbose)

    out2 = lapply(outfiles, antsImageRead)
    mask.lesion3 = out2$lesion_mask
    prediction2 = out2$prediction
  } else {

    print_msg('2nd round of prediction...', verbose=verbose)

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


  print_msg('3rd round of prediction...', verbose=verbose)
  outfiles = c(
    prediction = file.path(outdir,
                           'Prediction3.nii.gz'),
    lesion_mask = file.path(outdir, 'Mask.lesion4.nii.gz')
  )
  o = as.list(outfiles)
  names(o) = paste0(names(o), "_3")
  L = c(L, as.list(o))

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
    typeofTransform = "SyNCC",
    lesion_mask = mask.lesion3,
    reflaxis = reflaxis,
    sigma = sigma,
    verbose = verbose)

  prediction3 = out3$prediction
  antsImageWrite(prediction3, outfiles["prediction"])

  mask.lesion4 = out3$lesion_mask

  antsImageWrite(mask.lesion4, outfiles["lesion_mask"])

  reg3 = out3$registration
  reg_to_template = file.path(outdir, 'Reg3_registered_to_template.nii.gz')
  antsImageWrite(
    reg3$warpedfixout,
    reg_to_template
  )

  L$reg_to_template = reg_to_template

  reg_to_sub_warp = file.path(outdir, 'Reg3_template_to_sub_warp.nii.gz')
  file.copy(
    reg3$fwdtransforms[1],
    reg_to_sub_warp
  )
  L$reg_to_sub_warp = reg_to_sub_warp

  reg_to_sub_aff = file.path(outdir , 'Reg3_template_to_sub_affine.mat')
  file.copy(reg3$fwdtransforms[2],
            reg_to_sub_aff
  )

  L$reg_to_sub_aff = reg_to_sub_aff

  reg_to_temp_aff = file.path(outdir , 'Reg3_sub_to_template_affine.mat')
  L$reg_to_temp_aff = reg_to_temp_aff

  file.copy(reg3$invtransforms[1],
            reg_to_temp_aff
  )

  reg_to_temp_warp = file.path(outdir , 'Reg3_sub_to_template_warp.nii.gz')
  L$reg_to_temp_warp = reg_to_temp_warp
  file.copy(
    reg3$invtransforms[2],
    reg_to_temp_warp
  )

  seg = out3$segmentation

  seg_file = file.path(outdir, 'Prediction3_template.nii.gz')
  L$segmentation = seg_file

  antsImageWrite(seg, seg_file)

  print_msg("Saving 3rd final prediction in native space...",
            verbose = verbose)
  segnative_file = file.path(outdir, 'Prediction3_native.nii.gz')
  segnative = out3$segmentation_native

  L$segmentation_native = segnative_file
  antsImageWrite(segnative, segnative_file)

  graded_map = out3$multi_res_seg$probs[[1]][[4]]

  grad_file = file.path(outdir, 'Prediction3_graded_map.nii.gz')
  antsImageWrite(graded_map, grad_file)

  # save graded map
  probles = resampleImage(graded_map,
                          dim(tempbrain),
                          useVoxels = 1,
                          interpType = 0)
  # probles = resampleImageToTarget(
  #   image = graded_map,
  #   target = tempbrain,
  #   interpType = "nearestNeighbor")



  problesnative = antsApplyTransforms(
    fixed = simg,
    moving = probles,
    transformlist = reg3$fwdtransforms,
    interpolator = 'Linear',
    verbose = verbose > 1
  )
  probles_file = file.path(outdir,
                            'Prediction3_probability_template.nii.gz')
  L$lesion_probability_template = probles_file
  print_msg("Saving probabilistic prediction in template space...",
            verbose = verbose)
  antsImageWrite(probles, probles_file)

  problesnative_file = file.path(
    outdir, 'Prediction3_probability_native.nii.gz')
  L$lesion_probability_native = problesnative_file
  print_msg("Saving probabilistic prediction in native space...",
            verbose = verbose)
  antsImageWrite(problesnative, problesnative_file)


  # save in MNI coordinates
  print_msg("Transferring data in MNI (ch2) space...",
            verbose = verbose)

  # warppenn = file.path(outdir, 'Reg3_sub_to_template_warp.nii.gz')
  warppenn = reg_to_temp_warp
  # affpenn = file.path(outdir, 'Reg3_sub_to_template_affine.mat')
  affpenn = reg_to_temp_aff

  mni = system.file("extdata", "pennTemplate", "ch2.nii.gz",
                    package = "LINDA",
                    mustWork = TRUE)

  mni = antsImageRead(mni)

  warpmni = system.file("extdata", "pennTemplate",
                        "templateToCh2_1Warp.nii.gz",
                        package = "LINDA",
                        mustWork = FALSE)

  affmni = system.file("extdata",
                       "pennTemplate",
                       "templateToCh2_0GenericAffine.mat",
                       package = "LINDA",
                       mustWork = FALSE)
  if (!noMNI) {
    if (!all(file.exists(warpmni, affmni)) & !noMNI) {
      print_msg("No MNI transformations available, registering de novo\n     get full release to eleminate this step",
                verbose = verbose)
      temp_to_ch2 = antsRegistration(
        fixed = mni, moving = temp,
        typeofTransform = "SyNCC",
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
    t1_template = file.path(outdir, 'Subject_in_MNI.nii.gz')
    antsImageWrite(submni, t1_template)

    L$t1_template = t1_template

    print_msg("Saving lesion in MNI (ch2) space...",
              verbose = verbose)
    lesion_template = file.path(outdir, 'Lesion_in_MNI.nii.gz')
    L$lesion_template = lesion_template
    antsImageWrite(lesmni, lesion_template)
  } else {
    print_msg("Skipping data transformation in MNI (ch2) ...", verbose = verbose)
  }

  tic = Sys.time()
  runtime = paste(round(as.double(difftime(tic,toc)),1), units(difftime(tic,toc)))
  print_msg(paste('Done!',runtime, '\n'), verbose=verbose)

  }, split=TRUE, type='output') # end window capture

  logFile = file.path(outdir, 'Output.txt')
  writeLines(outputLog, logFile)


  # save environment data for transparency and reproducibility
  if ('devtools' %in% installed.packages()) {
    thisenvironment = devtools::session_info('LINDA')
  } else {
    thisenvironment = sessionInfo()
  }
  writeLines(suppressMessages(capture.output(thisenvironment)),
             file.path(outdir, 'Session_info.txt'))


  return(L)
}
