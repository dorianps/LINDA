## What is LINDA?  
Is a toolkit for automatic segmentation of lesions in __chronic__ stroke patients.   
*****  
##  Requirements:  
* Linux or Mac (ANTsR cannot run in Windows yet)  
* [R v3.0 or above](http://www.r-project.org/) 
* The [ANTsR](http://stnava.github.io/ANTsR/) package installed in R
* A T1-weighted MRI of a patient with (left hemispheric) stroke
 
*****  
## Install:  
Download the [latest release](https://github.com/dorianps/LINDA/releases/download/0.2.0/LINDA_v0.2.0.zip) (v0.2.0) and unzip in a local folder.  
  
_IMPORTANT: Use the above link for downloading. The Github download does not contain the large files with trained prediction models._  
  
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
>  12:09 Loading file: TMT_MPRAGE.nii  
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
15:02 Saving 3rd final prediction in native space...  
DONE  
  
  
Wonder what to expect? Check individual results from our  [60 patients Penn dataset](https://drive.google.com/file/d/0BxHeqEv37qqDT085MHAyMzFJcVk) and [45 patients Georgetown dataset](https://drive.google.com/open?id=0BxHeqEv37qqDY1psaC14QXZSOXc).  
  
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
  
## Support:  
The best way to keep track of bugs or failures is to open a [New Issue](https://github.com/dorianps/LINDA/issues) on the Github system. You can also contact the author via email: dorian dot pustina at uphs dot upenn dot edu (translate from english). If the algorithm proceeds without errors but the automatic segmentation is erroneous, please send (i) your T1 image and (ii) the segmentation produced by LINDA in native space. Try also overlaying `Mask.lesion*.nii.gz` files on the T1 to check whether the brain mask is wrong somewhere.  
  
