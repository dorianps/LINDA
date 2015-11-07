getLesionFeatures = function(img, template, featdir, bmask, truncate) {
  # function to compute features for MRV-NRF
  
  if ( any(dim(img) != dim(template)) ) {
    stop(paste('Image - template dimension mismatch',
                paste(dim(img),collapse='x'), 'vs.', 
                paste(dim(template),collapse='x'))  )
  }
  
  # # #  START FILLING FEATURES
  feats = list()
  
  # FEAT 1: kmean difference from controls
  conavg = antsImageRead(file.path(featdir,'sumkmean.nii.gz'))
  kmean = kmeansSegmentation(img,3,bmask)$segmentation
  feats[[1]] = (conavg - kmean) %>% iMath('Normalize')
  
  # FEAT 2: gradient magnitude
  feats[[2]] = img %>% iMath('Grad') %>% iMath('Normalize')
  
  # FEAT 3: t1 difference from controls
  conavg = antsImageRead(file.path(featdir,'N4ControlAvgerage.nii.gz'))
  temp = img %>% smoothImage(2) %>%
    iMath(truncate, 0.001, 0.999) %>% 
    iMath('Normalize')
  feats[[3]] = (conavg - temp) %>% 
    iMath(truncate, 0.01, 0.99) %>%
    iMath('Normalize')
  
  # FEAT 4: kmean
  feats[[4]] = antsImageClone(kmean)
  
  # FEAT 5: reflection difference from controls
  conavg = antsImageRead(file.path(featdir,'ControlAverageReflected.nii.gz'))
  reflimg = reflectImage(img, axis=1, tx='Affine')
  temp = iMath(reflimg$warpedmovout-img, truncate, 0.01, 0.99) %>% iMath('Normalize')
  feats[[5]] = (temp - conavg) %>% iMath('Normalize')
  
  # FEAT 6: t1 itself
  feats[[6]] = antsImageClone(img)   # iMath(img,'Normalize')
  
  return(feats)
}