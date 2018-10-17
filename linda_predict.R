ver = 'v0.2.7'
cat(paste(format(Sys.time(), "%H:%M") , 'Starting LINDA', ver, "...\n"))
#' Version History
#' 0.1   - first published LINDA
#' 0.2.0 - added native space output, added probability map output
#' 0.2.1 - fixed TruncateIntensity issue in old ANTsR
#'       - added MNI output
#' 0.2.2 - fix axis for left-right refelction
#' 0.2.3 - fix bug in 'relfaxis'
#' 0.2.4 - switching mask.lesion1 from graded to binary
#' 0.2.5 - fixed scriptdir to allow command line call
#' 0.2.6 - fixed bug in mrvnrfs_chunks.predict after dimfix 
#'         from @jeffduda in ANTsR (03/02/2017)
#'         removed dynamic set of reflaxis, all = 0 now
#' 0.2.7 - using splitMask for compatibility with new ANTsR
#'         reconfiguration of June 2017.

# check for necessary packages and load them
if (! is.element("ANTsR", installed.packages()[,1])) {
  stop("Required ANTsR package cannot be found.
        Automated installation not possible.
       See http://stnava.github.io/ANTsR for installation instructions")
} else {
  library(ANTsR)
}
if (! is.element("randomForest", installed.packages()[,1])) {
  print("Installing missing `randomForest` package")
  install.packages("randomForest")
  library(randomForest)
} else { 
  library(randomForest)
}


# parse arguments for command line use
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


# load the file
cat(paste(format(Sys.time(), "%H:%M") , 'Loading file:', basename(t1), "\n"))
subimg = antsImageRead(t1)
submask = subimg*0 + 1


# create linda folder
lindadir = file.path(dirname(t1), 'linda')
cat(paste(format(Sys.time(), "%H:%M") , 'Creating folder:', lindadir, "\n"))
dir.create(lindadir, showWarnings = F, recursive = T)


# fix TruncateIntensity incompatibility with old ANTsR binaries
if ( length( grep('TruncateIntensity' ,iMath(20,'GetOperations'))) != 0 ) {
  truncate = 'TruncateIntensity'
} else {
  truncate = 'TruncateImageIntensity'
}


# load other functions
if (!exists('scriptdir'))  scriptdir = dirname(sys.frame(1)$ofile)
source(file.path(scriptdir, 'getLesionFeatures.R'), echo=F)
source(file.path(scriptdir, 'mrvnrfs_chunks.R'), echo=F)


# load template files
cat(paste(format(Sys.time(), "%H:%M") , "Loading template... \n"))
temp = antsImageRead(file.path(scriptdir,'pennTemplate','template.nii.gz'))
tempbrain = antsImageRead(file.path(scriptdir,'pennTemplate','templateBrain.nii.gz'))
tempmask = antsImageRead(file.path(scriptdir,'pennTemplate','templateBrainMask.nii.gz'))



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
reflaxis = 0 # which.max(abs(antsGetDirection(simg)[,1]))-1

asymmetry = reflectImage(simg,axis=reflaxis, tx='Affine'); Sys.sleep(2)
antsImageWrite(asymmetry$warpedmovout, file.path(lindadir,'N4corrected_Brain_LRflipped.nii.gz'))
reflect = smoothImage(asymmetry$warpedmovout, 2) - smoothImage(simg, 2)
reflect[reflect<0]=0
reflect = iMath(reflect,'Normalize')
mask.lesion1 = submask - reflect
mask.lesion1 = thresholdImage(mask.lesion1,0.6,Inf) * submask
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
  iMath(truncate,0.01,0.99) %>% 
  iMath('Normalize')
tempmask=antsApplyTransforms(moving=submask, fixed=tempbrain,transformlist = reg1$invtransforms, interpolator = 'NearestNeighbor')

# prepare features
cat(paste(format(Sys.time(), "%H:%M") , "Feature calculation... \n"))
features = getLesionFeatures(reg1$warpedfixout, tempbrain, scriptdir,tempmask,truncate,reflaxis)
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
  iMath(truncate,0.01,0.99) %>% 
  iMath('Normalize')
tempmask=antsApplyTransforms(moving=submask, fixed=tempbrain,transformlist = reg2$invtransforms, interpolator = 'NearestNeighbor')

# prepare features
cat(paste(format(Sys.time(), "%H:%M") , "Feature calculation... \n"))
features = getLesionFeatures(reg2$warpedfixout, tempbrain, scriptdir, tempmask,truncate,reflaxis)
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
antsImageWrite(reg3$warpedfixout, file.path(lindadir,'Reg3_registered_to_template.nii.gz'))
file.copy(reg3$fwdtransforms[1], file.path(lindadir , 'Reg3_template_to_sub_warp.nii.gz'))
file.copy(reg3$fwdtransforms[2], file.path(lindadir , 'Reg3_template_to_sub_affine.mat'))
file.copy(reg3$invtransforms[1], file.path(lindadir , 'Reg3_sub_to_template_affine.mat'))
file.copy(reg3$invtransforms[2], file.path(lindadir , 'Reg3_sub_to_template_warp.nii.gz'))

reg3$warpedfixout = reg3$warpedfixout %>% 
  iMath(truncate,0.01,0.99) %>% 
  iMath('Normalize')
tempmask=antsApplyTransforms(moving=submask, fixed=tempbrain,transformlist = reg3$invtransforms, interpolator = 'NearestNeighbor')

# prepare features
cat(paste(format(Sys.time(), "%H:%M") , "Feature calculation... \n"))
features = getLesionFeatures(reg3$warpedfixout, tempbrain, scriptdir, tempmask,truncate,reflaxis)
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
cat(paste(format(Sys.time(), "%H:%M") , "Saving 3rd final prediction in template space... \n"))
antsImageWrite(seg, file.path(lindadir,'Prediction3_template.nii.gz'))
cat(paste(format(Sys.time(), "%H:%M") , "Saving 3rd final prediction in native space... \n"))
antsImageWrite(segnative, file.path(lindadir,'Prediction3_native.nii.gz'))

# save graded map
probles = resampleImage(mmseg3$probs[[1]][[4]], dim(tempbrain), useVoxels = 1, interpType = 0)
problesnative = antsApplyTransforms(fixed = simg, moving = probles, 
                                transformlist = reg3$fwdtransforms, interpolator = 'Linear')
cat(paste(format(Sys.time(), "%H:%M") , "Saving probabilistic prediction in template space... \n"))
antsImageWrite(probles, file.path(lindadir,'Prediction3_probability_template.nii.gz'))
cat(paste(format(Sys.time(), "%H:%M") , "Saving probabilistic prediction in native space... \n"))
antsImageWrite(problesnative, file.path(lindadir,'Prediction3_probability_native.nii.gz'))

# save in MNI coordinates
cat(paste(format(Sys.time(), "%H:%M") , "Transferring data in MNI (ch2) space... \n"))
warppenn = file.path(lindadir , 'Reg3_sub_to_template_warp.nii.gz')
affpenn = file.path(lindadir , 'Reg3_sub_to_template_affine.mat')
warpmni = file.path(scriptdir,'pennTemplate','templateToCh2_1Warp.nii.gz')
affmni = file.path(scriptdir,'pennTemplate','templateToCh2_0GenericAffine.mat')
mni = antsImageRead(
    file.path(scriptdir,'pennTemplate','ch2.nii.gz')
  )
matrices = c(warpmni,affmni,affpenn,warppenn)

submni=antsApplyTransforms(moving=simg, fixed=mni,transformlist = matrices, interpolator = 'Linear', whichtoinvert = c(0,0,1,0))
lesmni=antsApplyTransforms(moving=segnative, fixed=mni,transformlist = matrices, interpolator = 'NearestNeighbor', whichtoinvert = c(0,0,1,0))

cat(paste(format(Sys.time(), "%H:%M") , "Saving subject in MNI (ch2) space... \n"))
antsImageWrite(submni, file.path(lindadir,'Subject_in_MNI.nii.gz'))
cat(paste(format(Sys.time(), "%H:%M") , "Saving lesion in MNI (ch2) space... \n"))
antsImageWrite(lesmni, file.path(lindadir,'Lesion_in_MNI.nii.gz'))


cat('DONE')