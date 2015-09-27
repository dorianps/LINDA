# LINDA
Lesion Identification with Neighborhood Data Analysis  
*****  
##  Requirements:  
* Linux or Mac (ANTsR cannot run in Windows yet)  
* [R](http://www.r-project.org/) or, even better, [Rstudio](http://www.rstudio.com/products/rstudio/download/) 
* The [ANTsR](http://stnava.github.io/ANTsR/) package installed in R
* A T1-weighted MRI of a patient with (left hemispheric) stroke
 
*****  
## Install:  
Download the [latest release](https://github.com/dorianps/LINDA/releases/download/0.1/LINDA_v0.1.zip) and unzip in a local folder.  
  
_IMPORTANT: Do not use the Github download buttons. They provide only the files of the main repository, without the large files containing the trained prediction models. The above link points to a full release that contains also the prediction models._  
  
*****  
## Run:  
Open R and source the file linda_predict.R
`source('/data/myfolder/stroke/LINDA/linda_predict.R')`  
A file dialog will allow you to select the T1 nifti file of the patient with left hemispheric brain damage.  
LINDA will run and you will see the timestamp of the various steps.  
Results will be saved in a folder named "linda" in the same path where the T1 is located.  

  
 _Note, LINDA will stop if you don't have `ANTsR` installed, and will automatically install the `randomForest` package._  
  
  
## Available prediction models:  
_Currently a model from 60 patients from Penn is used. The model works at a maximum resolution of 2mm and contains three hierarchical steps (6mm, 4mm, 2mm). Other models might be available in the future._  
  
*****  
## Example:  
`source('/data/myfolder/stroke/LINDA/linda_predict.R')`  
>  10:42 Loading template...  
10:42 Creating folder: /data/jag/myhome/LINDAtest/linda  
10:42 Loading file: SybjectT1.nii  
10:42 Skull stripping... (long process)  
11:06 Saving skull stripped files  
11:06 Loading LINDA model  
11:06 Computing asymmetry mask...  
11:09 Saving asymmetry mask...   
11:09 Running 1st registration...   
11:16 Feature calculation...   
11:21 Running 1st prediction...   
11:22 Saving 1st prediction...   
11:22 Backprojecting 1st prediction...   
11:22 Running 2nd registration...   
11:29 Feature calculation...   
11:33 Running 2nd prediction...   
11:34 Saving 2nd prediction...  
11:34 Backprojecting 2nd prediction...  
11:34 Running 3rd registration... (long process)  
13:15 Saving 3rd registration results...  
13:15 Feature calculation...  
13:19 Running 3rd prediction...  
13:20 Saving 3rd final prediction...  
13:20 Saving 3rd final prediction in native space...  
DONE  
