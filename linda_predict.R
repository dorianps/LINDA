# load other functions
scriptdir = dirname(sys.frame(1)$ofile)
source(file.path(scriptdir, 'getLesionFeatures.R'), echo=F)
source(file.path(scriptdir, 'mrvnrfs_chunks.R'), echo=F)


# install necessary packages and load them
if (! is.element("ANTsR", installed.packages()[,1])) {
  stop("Required ANTsR package cannot be found.
        Automated installation not possible.
       See http://stnava.github.io/ANTsR for installation instructions")
}
if (! is.element("randomForest", installed.packages()[,1])) {
  print("Installing missing `randomForest` package")
  install.packages("randomForest")
}


# load template files
cat(paste(format(Sys.time(), "%H:%M") , "Loading template... \n"))
temp = antsImageRead(file.path(scriptdir,'pennTemplate','template.nii.gz'))
tempbrain = antsImageRead(file.path(scriptdir,'pennTemplate','templateBrain.nii.gz'))
tempmask = antsImageRead(file.path(scriptdir,'pennTemplate','templateBrainMask.nii.gz'))
                                                   

args=commandArgs(TRUE)
for(i in 1:length(args)){
  eval(parse(text=args[i]))
}


# select the file
if (! exists('t1')) {
  t1 = file.choose()
} else {
  if (! file.exists(t1)) {
    stop(paste( 'File inexistent:', t1 ))
  }
}

# check this is a nifti extension
if (length(grep(".nii$", t1)) == 0 & length(grep(".nii.gz$", t1)) == 0) {
  stop(
    paste( 'Unsupported file type ->', basename(t1) )
  )
}


# create linda folder
lindadir = file.path(dirname(t1), 'linda')
cat(paste(format(Sys.time(), "%H:%M") , 'Creating folder:', lindadir, "\n"))
dir.create(lindadir, showWarnings = F, recursive = T)

# load the file
cat(paste(format(Sys.time(), "%H:%M") , 'Loading file:', basename(t1), "\n"))
subimg = antsImageRead(t1)
submask = subimg*0 + 1


# two rounds of N4-BrainExtract to skull strip
cat(paste(format(Sys.time(), "%H:%M") , "Skull stripping... (long process) \n"))
for (i in 1:2) {
  n4 = abpN4(img = subimg, mask=submask)
  bextract = abpBrainExtraction(img = subimg, 
                                tem = temp,
                                temmask = tempmask)
  submask = bextract$bmask*1
}
simg = n4 * submask
cat(paste(format(Sys.time(), "%H:%M") , "Saving skull stripped files \n"))
antsImageWrite(n4, file.path(lindadir,'N4corrected.nii.gz'))
antsImageWrite(submask, file.path(lindadir,'BrainMask.nii.gz'))
antsImageWrite(simg, file.path(lindadir,'N4corrected_Brain.nii.gz'))

cat(paste(format(Sys.time(), "%H:%M") , "Loading LINDA model \n"))
load(file.path(scriptdir, 'PublishablePennModel_2mm_mr321_rad1.Rdata'))


# compute asymmetry mask
cat(paste(format(Sys.time(), "%H:%M") , "Computing asymmetry mask... \n"))
if (sum( abs(diag(antsGetDirection(simg))) ) == 3) {
  reflaxis = 1
} else {
  reflaxis = 0
}
asymmetry = reflectImage(simg,axis=reflaxis, tx='Affine'); Sys.sleep(2)
antsImageWrite(asymmetry$warpedmovout, file.path(lindadir,'N4corrected_Brain_LRflipped.nii.gz'))
reflect = smoothImage(asymmetry$warpedmovout, 2) - smoothImage(simg, 2)
reflect[reflect<0]=0
reflect = iMath(reflect,'Normalize')
mask.lesion1 = submask - reflect
mask.lesion1 [mask.lesion1<0.2] = 0
mask.lesion1[submask==0] = 0
cat(paste(format(Sys.time(), "%H:%M") , "Saving asymmetry mask... \n"))
antsImageWrite(mask.lesion1, file.path(lindadir,'Mask.lesion1_asym.nii.gz'))


# half brain mask
resamplevox = c(2,2,2)
brainmask=iMath(tempmask, 'MD', 1)
emptyimg = brainmask*1; emptyimg=as.array(emptyimg); emptyimg[ 1:91 , ,]=0
brainmaskleftbrain = resampleImage(brainmask*emptyimg, resamplevox, 0, 1) 
rm(emptyimg)


################################ 1st registration 
cat(paste(format(Sys.time(), "%H:%M") , "Running 1st registration... \n"))
reg1=antsRegistration(fixed=simg,moving=tempbrain,typeofTransform = 'SyN',mask=mask.lesion1)
reg1$warpedfixout = reg1$warpedfixout %>% 
  iMath('TruncateIntensity',0.01,0.99) %>% 
  iMath('Normalize')

# prepare features
cat(paste(format(Sys.time(), "%H:%M") , "Feature calculation... \n"))
features = getLesionFeatures(reg1$warpedfixout, tempbrain, scriptdir)
for (i in 1:length(features)) features[[i]] = resampleImage(features[[i]], resamplevox, 
                                                            useVoxels = 0, interpType = 0) * brainmaskleftbrain

# 1st prediction
cat(paste(format(Sys.time(), "%H:%M") , "Running 1st prediction... \n"))
predlabel.sub = brainmaskleftbrain*1;
predlabel.sub[features[[4]] == 0] = 0
mmseg1<-suppressMessages(
  mrvnrfs.predict_chunks( rfm$rflist, list(features),
                               predlabel.sub, rad=rad,
                               multiResSchedule=mr, voxchunk=5000 )
)
cat(paste(format(Sys.time(), "%H:%M") , "Saving 1st prediction... \n"))
antsImageWrite(mmseg1$seg[[1]], file.path(lindadir,'Prediction1.nii.gz'))

# backproject
cat(paste(format(Sys.time(), "%H:%M") , "Backprojecting 1st prediction... \n"))
seg = resampleImage(mmseg1$seg[[1]], dim(tempbrain), useVoxels = 1, interpType = 1)
seg[seg!=4]=0
seg[seg==4]=1
segnative = antsApplyTransforms(fixed = simg, moving = seg, 
                                transformlist = reg1$fwdtransforms, interpolator = 'NearestNeighbor')
mask.lesion2=submask*1
mask.lesion2[segnative==1]=0
antsImageWrite(mask.lesion2, file.path(lindadir,'Mask.lesion2.nii.gz'))



########################### 2nd registration 
cat(paste(format(Sys.time(), "%H:%M") , "Running 2nd registration... \n"))
reg2=antsRegistration(fixed=simg,moving=tempbrain,typeofTransform = 'SyN',mask=mask.lesion2)
reg2$warpedfixout = reg2$warpedfixout %>% 
  iMath('TruncateIntensity',0.01,0.99) %>% 
  iMath('Normalize')

# prepare features
cat(paste(format(Sys.time(), "%H:%M") , "Feature calculation... \n"))
features = getLesionFeatures(reg2$warpedfixout, tempbrain, scriptdir)
for (i in 1:length(features)) features[[i]] = resampleImage(features[[i]], resamplevox, 
                                                            useVoxels = 0, interpType = 0) * brainmaskleftbrain

# 2nd prediction
cat(paste(format(Sys.time(), "%H:%M") , "Running 2nd prediction... \n"))
predlabel.sub = brainmaskleftbrain*1;
predlabel.sub[features[[4]] == 0] = 0
mmseg2<-suppressMessages(
  mrvnrfs.predict_chunks( rfm$rflist, list(features),
                                predlabel.sub, rad=rad,
                                multiResSchedule=mr, voxchunk=5000 )
)
cat(paste(format(Sys.time(), "%H:%M") , "Saving 2nd prediction... \n"))
antsImageWrite(mmseg2$seg[[1]], file.path(lindadir,'Prediction2.nii.gz'))

# backproject
cat(paste(format(Sys.time(), "%H:%M") , "Backprojecting 2nd prediction... \n"))
seg = resampleImage(mmseg2$seg[[1]], dim(tempbrain), useVoxels = 1, interpType = 1)
seg[seg!=4]=0
seg[seg==4]=1
segnative = antsApplyTransforms(fixed = simg, moving = seg, 
                                transformlist = reg2$fwdtransforms, interpolator = 'NearestNeighbor')
mask.lesion3=submask*1
mask.lesion3[segnative==1]=0
antsImageWrite(mask.lesion3, file.path(lindadir,'Mask.lesion3.nii.gz'))



########################### 3rd registration 
cat(paste(format(Sys.time(), "%H:%M") , "Running 3rd registration... (long process)\n"))
reg3=antsRegistration(fixed=simg,moving=tempbrain,typeofTransform = 'SyNCC',mask=mask.lesion3)
# save reg3 results
cat(paste(format(Sys.time(), "%H:%M") , "Saving 3rd registration results... \n"))
antsImageWrite(reg3$warpedfixout, file.path(lindadir,'Reg3_registered.nii.gz'))
file.copy(reg3$fwdtransforms[1], file.path(lindadir , 'Reg3_template_to_sub_warp.nii.gz'))
file.copy(reg3$fwdtransforms[2], file.path(lindadir , 'Reg3_template_to_sub_affine.mat'))
file.copy(reg3$invtransforms[1], file.path(lindadir , 'Reg3_sub_to_template_affine.mat'))
file.copy(reg3$invtransforms[2], file.path(lindadir , 'Reg3_sub_to_template_warp.nii.gz'))

reg3$warpedfixout = reg3$warpedfixout %>% 
  iMath('TruncateIntensity',0.01,0.99) %>% 
  iMath('Normalize')

# prepare features
cat(paste(format(Sys.time(), "%H:%M") , "Feature calculation... \n"))
features = getLesionFeatures(reg3$warpedfixout, tempbrain, scriptdir)
for (i in 1:length(features)) features[[i]] = resampleImage(features[[i]], resamplevox, 
                                                            useVoxels = 0, interpType = 0) * brainmaskleftbrain

# 3rd prediction
cat(paste(format(Sys.time(), "%H:%M") , "Running 3rd prediction... \n"))
predlabel.sub = brainmaskleftbrain*1;
predlabel.sub[features[[4]] == 0] = 0
mmseg3<-suppressMessages(
  mrvnrfs.predict_chunks( rfm$rflist, list(features),
                                predlabel.sub, rad=rad,
                                multiResSchedule=mr, voxchunk=5000 )
)
cat(paste(format(Sys.time(), "%H:%M") , "Saving 3rd final prediction... \n"))
antsImageWrite(mmseg3$seg[[1]], file.path(lindadir,'Prediction3.nii.gz'))


# backproject to save
seg = resampleImage(mmseg3$seg[[1]], dim(tempbrain), useVoxels = 1, interpType = 1)
seg[seg!=4]=0
seg[seg==4]=1
segnative = antsApplyTransforms(fixed = simg, moving = seg, 
                                transformlist = reg3$fwdtransforms, interpolator = 'NearestNeighbor')
cat(paste(format(Sys.time(), "%H:%M") , "Saving 3rd final prediction in native space... \n"))
antsImageWrite(segnative, file.path(lindadir,'Prediction3_native.nii.gz'))
cat('DONE')