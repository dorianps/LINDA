## What is LINDA?  
Is a toolkit for automatic segmentation of lesions in __chronic__ stroke patients.   
*****  
##  Requirements:  
* Linux or Mac (ANTsR cannot run in Windows yet)  
* [R](http://www.r-project.org/) or, even better, [Rstudio](http://www.rstudio.com/products/rstudio/download/) 
* The [ANTsR](http://stnava.github.io/ANTsR/) package installed in R
* A T1-weighted MRI of a patient with (left hemispheric) stroke
 
*****  
## Install:  
Download the [latest release](https://github.com/dorianps/LINDA/releases/download/0.1/LINDA_v0.1.zip) (v0.1) and unzip in a local folder.  
  
_IMPORTANT: Do not use the Github download buttons. They provide only the files of the main repository, without the large files containing the trained prediction models. The above link points to a full release that contains also the prediction models._  
  
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
## Support:  
Best way to keep track of bugs or failures is to open a [New Issue](https://github.com/dorianps/LINDA/issues) on the Github system. You can also contact the author via email: dorian dot pustina at uphs dot upenn dot edu (translate from english). If the automatic segmentation is produced by is erronous, please send (i) your T1 image and (ii) the segmentation produced by LINDA in native space.  
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


To form an idea of the prediction accuracy, check individual samples from our  [main](https://github.com/dorianps/LINDA/blob/master/Individual_Predictions_UPenn_Dataset.pdf) and [complementary](https://github.com/dorianps/LINDA/blob/master/Individual_Predictions_Georgetown_Dataset.pdf) datasets.

