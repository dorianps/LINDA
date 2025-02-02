
[![Travis build
status](https://travis-ci.org/dorianps/LINDA.svg?branch=master)](https://travis-ci.org/dorianps/LINDA)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/ed7c8fb5034e40bfbb12ddbf827078ed)](https://www.codacy.com/manual/dorianps/LINDA?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=dorianps/LINDA&amp;utm_campaign=Badge_Grade)
[![DOI](https://zenodo.org/badge/43025021.svg)](https://zenodo.org/badge/latestdoi/43025021)
[![RRID badge](https://img.shields.io/badge/RRID-SCR__017971-blue.svg)](#)
<!--
[![AppVeyor Build Status](https://ci.appveyor.com/api/projects/status/github/muschellij2/LINDA?branch=master&svg=true)](https://ci.appveyor.com/project/muschellij2/LINDA)
[![Coverage status](https://codecov.io/gh/muschellij2/LINDA/branch/master/graph/badge.svg)](https://codecov.io/gh/muschellij2/LINDA)
-->

<!-- README.md is generated from README.Rmd. Please edit that file -->

# LINDA Package:

`LINDA` is an R package for automatic segmentation of **chronic** stroke
lesions.  
The method is described in [Hum Brain Mapp. 2016
Apr;37(4):1405-21](http://onlinelibrary.wiley.com/doi/10.1002/hbm.23110/abstract).

-----

## Requirements:

  - Linux or Mac (since Oct 2016 ANTsR [can run in Windows
    10](https://github.com/stnava/ANTsR/wiki/Installing-ANTsR-in-Windows-10-\(along-with-FSL,-Rstudio,-Freesurfer,-etc\).))  
  - [R v3.0 or above](http://www.r-project.org/)  
  - The [ANTsR](http://stnava.github.io/ANTsR/) package installed in R
  - A T1-weighted MRI of a patient with (left hemispheric) stroke

-----

## Installation:

##### Method 1 (easy, incomplete)

This method does not require any prep on your side, just paste the lines
below and all required packages will (hopefully) be installed (including
ANTsR). However, MNI transformations are not included because Github
does not accept big files. You can still force on the fly registrations
to MNI (ch2) space by setting `saveMNI=TRUE`. If you frequently need
outputs in MNI space, use Method 2 below.

``` r
install.packages('devtools')
devtools::install_github('dorianps/LINDA', upgrade_dependencies=FALSE)
```

##### Method 2 (complex, complete)

This method includes the MNI transformations, but works only if you have
previously installed ANTsR. To do that, try:

``` r
devtools::install_github('ANTsX/ANTsR')
```

Then download the [latest LINDA release
v0.5.1](https://github.com/dorianps/LINDA/releases/download/0.5.1/LINDA_v0.5.1.zip)
and install from command line:

``` bash

wget https://github.com/dorianps/LINDA/releases/download/0.5.1/LINDA_v0.5.1.zip
unzip LINDA_v0.5.1.zip # this will unzip to LINDA folder
R CMD INSTALL LINDA # install the LINDA folder in R
```

## Docker container
You can get LINDA pre-installed in a docker container (along with RStudio), no need to install anything if you have Docker.  
We have built scripts for one-click start and stop of containers (Windows/Linux/Mac):  
https://github.com/dorianps/docker   
The list of current and past container builds is [here](https://hub.docker.com/r/dorianps/linda/tags)  


## Run: 

``` r
library(LINDA)
filename = '/path/to/patient/T1.nii.gz'
outputs = linda_predict(filename)
```

If you don’t specify a filename, a file dialog will allow you to choose
the T1 nifti file of the patient.

``` r
outputs = linda_predict()
```

LINDA will run and you will see the timestamp of the various steps.
Results will be saved in a folder named “linda” in the same path where
the T1 is located. The location of these files will be returned in R
(i.e., in the `outputs` variable).

If the “linda” folder contains segmentations from an earlier run,
processing will stop immediately. Use `cache=FALSE` to force overwriting
the old files. If processing is interrupted and restarted, LINDA will
use the existing files in the “linda” folder to start where it was
interrupted.

**Available prediction models:**  
*Currently a model trained on 60 patients from Penn is used. The
internal prediction engine works with 2mm voxel resolution. This does
not mean your images need to be 2mm, any resolution should work.*

-----

### Example:

\*(a somewhat slow example run on a single CPU core)

``` r
21:18 Starting LINDA v0.5.0
21:18 Creating folder: /data/jux/dpustina/LINDA_package/Sample_ABC/linda
21:18 Loading file: ABC_MPRAGE.nii ...
21:18 Loading template...
21:18 Skull stripping... (long process)
21:46 Saving skull stripped files...
21:46 Computing asymmetry mask...
21:50 Saving asymmetry mask...
21:50 1st round of prediction...
21:50     Running registration: SyN
21:57     Feature calculation 
22:02     Lesion segmentation
22:04 Backprojecting prediction...
22:04 Saving prediction...
22:04 2nd round of prediction...
22:04     Running registration: SyN
22:11     Feature calculation 
22:16     Lesion segmentation
22:17 Backprojecting prediction...
22:17 3rd round of prediction...
22:17     Running registration: SyNCC
00:44     Feature calculation 
00:49     Lesion segmentation
00:50 Backprojecting prediction...
00:50 Saving 3rd final prediction in native space...
00:51 Saving probabilistic prediction in template space...
00:51 Saving probabilistic prediction in native space...
00:51 Skipping data transformation in MNI (ch2) ...
00:51 Done! 3.5 hours 
```

Wonder what to expect? Check individual results from our [60 patients
Penn
dataset](https://drive.google.com/file/d/0BxHeqEv37qqDT085MHAyMzFJcVk)
and [45 patients Georgetown
dataset](https://drive.google.com/open?id=0BxHeqEv37qqDY1psaC14QXZSOXc).  
Our users have reported quite good lesion segmentations for typical
large stroke lesions, but less accurate segmentations with tiny lesions.

-----

##### OUTPUT files:

**BrainMask.nii.gz** - Brain mask used to skull strip (native space)  
**N4corrected.nii.gz** - Bias corrected, full image (native space)  
**N4corrected\_Brain.nii.gz** - Bias corrected, brain only (native
space)  
**N4corrected\_Brain\_LRflipped.nii.gz** - Flipped image used to compute
asymmetry mask (native space)  
**Mask.lesion(1)(2)(3).nii.gz** - masks used for registrations (native
space)  
**Prediction(1)(2)(3).nii.gz** - lesion predictions after each iteration
(template space, but 2mm)  
**Prediction3\_template.nii.gz** - final prediction (template space)  
**Prediction3\_native.nii.gz** - final prediction (native space)  
**Prediction3\_probability\_template.nii.gz** - final graded probability
(template space)  
**Prediction3\_probability\_native.nii.gz** - final graded probability
(native space)  
**Reg3\_registered\_to\_template.nii.gz** - Subject’s MRI, skull
stripped, bias corrected, registered to template (template space)  
**Reg3\_sub\_to\_template\_(affine)(warp)** - transformation matrices to
register subject to template  
**Reg3\_template\_to\_sub\_(affine)(warp)** - transformation matrices to
backproject template to subject  
**Subject\_in\_MNI.nii.gz** - Subject’s MRI, skull stripped, bias
corrected, transformed in MNI space  
**Lesion\_in\_MNI.nii.gz** - Lesion mask in MNI spacethe
**Console\_Output.txt** - log file replicating the console output
**Session\_Info.txt** - R environment and package versions, useful if
you want to reproduce the results in the future.

-----

**Important Note**  
MNI is a space, not a template. There are many templates in MNI space,
most of which do not have the same gyri or sulci at the same
coordinates. LINDA uses the CH2 template which is included in LINDA.
Please don’t use other MNI templates to overlay results. They may look
good from a first look, but they will be wrong. Use the CH2 template
that comes with LINDA. In alternative, you can register the CH2 template
to another template (i.e., ICBM 2009a) and transform back and forth the
results as necessary.

-----

## Frequently Asked Questions

**- What file formats are accepted**?  
Nifti images (.nii and .nii.gz) are accepted. Earlier LINDA versions did
not accept other formats, but now any format can be read. Note that the
Analyze format has unclear left-right orientation.  
**- Can I use it with right hemispheric lesions?**  
Yes, but you need to flip the L-R orientation before. After that, the
prediction will work just as well.  
**- Can I use it with bilateral lesions?**  
It will likely be less accurate. One of the features LINDA uses is the
left-right signal asymmetry.  
**- Can I use it to segment acute and subacute stroke lesions?**  
No, the current model is trained only on chronic stroke patients. It
might be possible to segment acute stroke with models trained on acute
data.  
**- Can I use other images: FLAIR, T2, DWI?**  
No, the existing model accepts only T1w. In principle, additional models
can be built from other modalities (T2, FLAIR, DWI).  
**- Can I train a model with my own data?**  
This is perfectly doable, but the training script is not available
online (needs some work to adapt it for widepsread use). If you want the
example script used for the current model, I can send it easily, just
contact me.  
**- Can I use LINDA to obtain registrations in MNI?**  
The transfer in MNI is obtained by concatenating transformations
“Subject” -\> “Penn Template” -\> “ch2 MNI template”. Thus there are
two sources of potential error. The second source of error is fixed for
all subjects because our template has always the same registration on
MNI. However, a fixed error is always an error. If you really want
precise registration on MNI, I advise to register directly the subject
to an MNI template (possibly using a group MNI template rather than the
ch2).  
**- Will you maintain LINDA and publish new models in the future?**  
There is no plan, time, or funding to do this at this time. If other
researchers want to contribute, this can be done easily because LINDA is
open source.

## Support:

The best way to keep track of bugs or failures is to open a [New
Issue](https://github.com/dorianps/LINDA/issues) on the Github system.
If the algorithm proceeds without errors but the automatic segmentation
is erroneous, please send (i) your T1 image and (ii) the segmentation
produced by LINDA in native space. Try also overlaying
`Mask.lesion*.nii.gz` files on the T1 to check whether the brain mask is
wrong somewhere.


### Authors

Dorian Pustina  
John Muschelli

## Other software for lesion studies

Check out the LESYMAP package for lesion to symptom mapping:
<https://github.com/dorianps/LESYMAP>.
