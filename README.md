###### Jan 19 - Announcement: We are preparing to release an improved version of LINDA. Please register to our mailing list to receive notifications of new releases, by sending an email to LINDA-tools+subscribe@googlegroups.com .  
  
## What is LINDA?  
Is a neuroimaging toolkit for automatic segmentation of  __chronic__ stroke lesions.   
*****  
##  Requirements:  
* Linux or Mac (ANTsR cannot run in Windows yet)  
* [R v3.0 or above](http://www.r-project.org/) 
* The [ANTsR](http://stnava.github.io/ANTsR/) package installed in R
* A T1-weighted MRI of a patient with (left hemispheric) stroke
 
*****  
## Install:  
Download the [latest release](https://github.com/dorianps/LINDA/releases/download/0.2.2/LINDA_v0.2.2.zip) (v0.2.2, 580Mb) and unzip in a local folder.  
  
_IMPORTANT: Only the above link contains the full release with trained models, templates, etc. Do not use the "Download" button at it contains only smaller scripts without trained models, etc._  
  
*****  
## Run:  
Open R and source the file linda_predict.R
`source('/data/myfolder/stroke/LINDA/linda_predict.R')`  
A file dialog will allow you to select the T1 nifti file of the patient with left hemispheric brain damage.  
LINDA will run and you will see the timestamp of the various steps.  
Results will be saved in a folder named "linda" in the same path where the T1 is located.  

  
 _Note, LINDA will stop if you don't have `ANTsR` installed, and will automatically install the `randomForest` package._  
  
  
**Available prediction models:**  
_Currently a model trained on 60 patients from Penn is used. The internal prediction engine works with 2mm voxel resolution. This does not mean your images need to be 2mm, any resolution should work._  
  
*****  
## Example:  
`source('/data/myfolder/stroke/LINDA/linda_predict.R')`  
>  12:09 Starting LINDA v0.2.1 ...  
12:09 Loading file: TMT_MPRAGE.nii  
12:09 Creating folder: /data/jag/dp/LINDAtest/TMT/linda  
12:09 Loading template...  
12:09 Skull stripping... (long process)  
12:34 Saving skull stripped files  
12:34 Loading LINDA model  
12:34 Computing asymmetry mask...  
12:38 Saving asymmetry mask...  
12:38 Running 1st registration...  
12:45 Feature calculation...  
12:50 Running 1st prediction...  
12:51 Saving 1st prediction...   
12:51 Backprojecting 1st prediction...  
12:51 Running 2nd registration...  
12:57 Feature calculation...  
13:01 Running 2nd prediction...  
13:02 Saving 2nd prediction...  
13:02 Backprojecting 2nd prediction...  
13:02 Running 3rd registration... (long process)  
14:56 Saving 3rd registration results...  
14:56 Feature calculation...  
15:01 Running 3rd prediction...  
15:02 Saving 3rd final prediction...  
15:02 Saving 3rd final prediction in template space...  
15:02 Saving 3rd final prediction in native space...  
15:02 Saving probabilistic prediction in template space...  
15:02 Saving probabilistic prediction in native space...  
15:02 Transferring data in MNI space...  
15:02 Saving subject in MNI space...  
15:02 Saving lesion in MNI space...  
DONE  
  
  
Wonder what to expect? Check individual results from our  [60 patients Penn dataset](https://drive.google.com/file/d/0BxHeqEv37qqDT085MHAyMzFJcVk) and [45 patients Georgetown dataset](https://drive.google.com/open?id=0BxHeqEv37qqDY1psaC14QXZSOXc).  
  
*****
## OUTPUT files:  
__BrainMask.nii.gz__ - Brain mask used to skull strip (native space)  
__N4corrected.nii.gz__ - Bias corrected, full image (native space)  
__N4corrected_Brain.nii.gz__ - Bias corrected, brain only (native space)  
__N4corrected_Brain_LRflipped.nii.gz__ - Flipped image used to compute asymmetry mask (native space)  
__Mask.lesion(1)(2)(3).nii.gz__ - masks used for registrations (native space)  
__Prediction(1)(2)(3).nii.gz__ - lesion predictions after each iteration (template space, but 2mm)  
__Prediction3_template.nii.gz__ - final prediction (template space)  
__Prediction3_native.nii.gz__ - final prediction (native space)  
__Prediction3_probability_template.nii.gz__ - final graded probability (template space)  
__Prediction3_probability_native.nii.gz__ - final graded probability (native space)  
__Reg3_registered_to_template.nii.gz__ - Subject's MRI, skull stripped, bias corrected, registered to template (template space)  
__Reg3_sub_to_template_(affine)(warp)__ - transformation matrices to register subject to template  
__Reg3_template_to_sub_(affine)(warp)__ - transformation matrices to backproject template to subject  
__Subject_in_MNI.nii.gz__ - Subject's MRI, skull stripped, bias corrected, transformed in MNI space  
__Lesion_in_MNI.nii.gz__ - Lesion mask in MNI space  
  
*****  
## Frequently Asked Questions
__- What file formats are accepted__?  
Nifti images (.nii and .nii.gz) are accepted. The platform can read many other formats, but we have limited the script to Nifti in order to avoid confusion with some formats (i.e., Analyze) that have unclear left-right orientation.  
__- Can I use it with right hemispheric lesions?__  
Yes, but you need to flip the L-R orientation before. After that, the prediction will work just as well. We plan to extend the script in the future for use in both left and right lesions.  
__- Can I use it with bilateral lesions?__  
It will likely be less accurate. One of the features we use is related to the left-right signal asymmetry  
__- Can I use it to segment acute and subacute stroke lesions?__  
No, the current model is trained only on chronic stroke patients. It might be possible to segment acute stroke with models trained on acute data (let us know if you want to contribute with those data).  
__- Can I use other images: FLAIR, T2, DWI?__  
The existing model uses only a T1, but we can adapt it with additional T2, FLAIR, DWI. We are open to collaborations with groups that have multimodal data and want to train LINDA with those. Having ~30 subjects is a good start.   
__- Can I train a model with my own data?__  
This is perfectly doable, but we haven't made available the script online yet (needs some work to adapt it for widepsread use). If you are in a hurry, contact us and we will send the current version of the training script.  
__- Can I use LINDA to obtain registrations in MNI?__  
The transfer in MNI is obtained by concatenating transformations "Subject" -> "Penn Template" -> "ch2 MNI template". Thus there are two sources of potential error. The second source of error is fixed for all subjects because our template has always the same registration on MNI. However, a fixed error is always an error. If you really want precise registration on MNI, we advise to register directly the subject to an MNI template (possibly using a group MNI template rather than the ch2).  
  
## Support:  
The best way to keep track of bugs or failures is to open a [New Issue](https://github.com/dorianps/LINDA/issues) on the Github system. You can also contact the author via email: dorian dot pustina at uphs dot upenn dot edu (translate from english). If the algorithm proceeds without errors but the automatic segmentation is erroneous, please send (i) your T1 image and (ii) the segmentation produced by LINDA in native space. Try also overlaying `Mask.lesion*.nii.gz` files on the T1 to check whether the brain mask is wrong somewhere.  
  
