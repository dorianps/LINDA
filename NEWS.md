# LINDA 0.5.0
* Full rewrite to make an R package
* Use existing outputs as cache to continue interrupted runs
* Enabled 'cache' argument to overwrite if necessary
* Github repository sufficient for R package install
* Console output and other R info saved in output folder
* Enabled travis build status
* Enabled automatic check of new versions onAttach
* Tested on ANTsR versions of late 2017 and late 2018


# LINDA 0.2.7 

* using splitMask for compatibility with new ANTsR
    reconfiguration of June 2017.
* Added a `NEWS.md` file to track changes to the package.

# LINDA 0.2.6 
* fixed bug in mrvnrfs_chunks.predict after dimfix from @jeffduda in ANTsR (03/02/2017) removed dynamic set of reflaxis, all = 0 now

# LINDA 0.2.5 
* fixed scriptdir to allow command line call

# LINDA 0.2.4 
* switching mask.lesion1 from graded to binary

# LINDA 0.2.3 
* fix bug in 'relfaxis'

# LINDA 0.2.2
* fix axis for left-right refelction

# LINDA 0.2.1 
* fixed TruncateIntensity issue in old ANTsR
* added MNI output

# LINDA 0.2.0 
* added native space output, added probability map output

# LINDA 0.1  
* first published LINDA
