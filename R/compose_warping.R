compose_warping = function() {
  warpmni = system.file("extdata", "pennTemplate",
                        "templateToCh2_1Warp.nii.gz",
                        package = "LINDA",
                        mustWork = FALSE)

  if (!file.exists(warpmni)) {
    transforms = sapply(
      0:2,
      function(x) {
        system.file(
          "extdata", "pennTemplate",
          paste0("templateToCh2_1Warp_000", x, ".nii.gz"),
          package = "LINDA",
          mustWork = TRUE)
      })
    res_img = composeTransformsToField(
      image = mni,
      transforms = transforms)
    outfile = tempfile(fileext = ".nii.gz")
    antsImageWrite(res_img, outfile)
    return(outfile)
  } else {
    return(warpmni)
  }
}
