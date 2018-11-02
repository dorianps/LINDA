n4_skull_strip = function(
  file,
  template = system.file("extdata", "pennTemplate", "template.nii.gz",
                         package = "LINDA"),
  template_brain = system.file("extdata", "pennTemplate", "templateBrain.nii.gz",
                               package = "LINDA"),
  template_mask = system.file("extdata", "pennTemplate", "templateBrainMask.nii.gz",
                              package = "LINDA"),
  verbose = TRUE,
  n_iter = 2) {

  # load the file
  print_msg('Loading file:', verbose = verbose)
  reader = function(x) {
    if (!is.antsImage(x)) {
      y = antsImageRead(x)
    } else {
      y = antsImageClone(x)
    }
    return(y)
  }
  subimg = reader(file)
  submask = subimg * 0 + 1
  # load template files

  print_msg("Loading template...", verbose = verbose)


  temp = reader(template)
  tempbrain = reader(template_brain)
  tempmask =  reader(template_mask)

  # two rounds of N4-BrainExtract to skull strip
  print_msg("Skull stripping... (long process)", verbose = verbose)
  for (i in 1:n_iter) {
  	print_msg(
  		paste0("Running iteration ", i),
  		verbose = verbose)
    n4 = abpN4(
      img = subimg,
      mask = submask)
    bextract = abpBrainExtraction(
      img = subimg,
      tem = temp,
      temmask = tempmask)
    submask = bextract$bmask * 1
  }
  simg = n4 * submask

  L = list(n4 = n4,
           brain_mask = submask,
           n4_brain = simg)
  return(L)
}
