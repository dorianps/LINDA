#' multi-res voxelwise neighborhood random forest segmentation learning
#'
#' Represents multiscale feature images as a neighborhood and uses the features
#' to build a random forest segmentation model from an image population
#'
#' @param y list of training labels. either an image or numeric value
#' @param x a list of lists where each list contains feature images
#' @param labelmask a mask for the features (all in the same image space)
#' the labelmask defines the number of parallel samples that will be used
#' per subject sample. two labels will double the number of predictors
#' contributed from each feature image.
#' @param rad vector of dimensionality d define nhood radius
#' @param nsamples (per subject to enter training)
#' @param ntrees (for the random forest model)
#' @param multiResSchedule an integer vector defining multi-res levels
#' @param asFactors boolean - treat the y entries as factors
#' @return list a 4-list with the rf model, training vector, feature matrix
#' and the random mask
#' @author Avants BB, Tustison NJ, Pustina D
#'
#' @examples
#'
#' mask<-makeImage( c(10,10), 0 )
#' mask[ 3:6, 3:6 ]<-1
#' mask[ 5, 5:6]<-2
#' ilist<-list()
#' lablist<-list()
#' inds<-1:50
#' scl<-0.33 # a noise parameter
#' for ( predtype in c("label","scalar") )
#' {
#' for ( i in inds ) {
#'   img<-antsImageClone(mask)
#'   imgb<-antsImageClone(mask)
#'   limg<-antsImageClone(mask)
#'   if ( predtype == "label") {  # 4 class prediction
#'     img[ 3:6, 3:6 ]<-rnorm(16)*scl+(i %% 4)+scl*mean(rnorm(1))
#'     imgb[ 3:6, 3:6 ]<-rnorm(16)*scl+(i %% 4)+scl*mean(rnorm(1))
#'     limg[ 3:6, 3:6 ]<-(i %% 4)+1  # the label image is constant
#'     }
#'     if ( predtype == "scalar") {
#'       img[ 3:6, 3:6 ]<-rnorm(16,1)*scl*(i)+scl*mean(rnorm(1))
#'       imgb[ 3:6, 3:6 ]<-rnorm(16,1)*scl*(i)+scl*mean(rnorm(1))
#'       limg<-i^2.0  # a real outcome
#'       }
#'     ilist[[i]]<-list(img,imgb)  # two features
#'     lablist[[i]]<-limg
#'   }
#' rad<-rep( 1, 2 )
#' mr <- c(1.5,1)
#' rfm<-mrvnrfs( lablist , ilist, mask, rad=rad, multiResSchedule=mr,
#'      asFactors = (  predtype == "label" ) )
#' rfmresult<-mrvnrfs.predict( rfm$rflist,
#'      ilist, mask, rad=rad, asFactors=(  predtype == "label" ),
#'      multiResSchedule=mr )
#' if ( predtype == "scalar" )
#'   print( cor( unlist(lablist) , rfmresult$seg ) )
#' } # end predtype loop
#'
#'
#' @export mrvnrfs
mrvnrfs_chunks <- function( y, x, labelmask, rad=NA, nsamples=1,
                     ntrees=500, multiResSchedule=c(4,2,1), asFactors=TRUE,
                     voxchunk=1000) {
  library(randomForest)
  # check y type
  yisimg<-TRUE
  if ( typeof(y[[1]]) == "integer" | typeof(y[[1]]) == "double") yisimg<-FALSE
  rflist<-list()
  rfct<-1

  mrcount=0
  for ( mr in multiResSchedule )
  {
    mrcount=mrcount+1

    if (mr != 1) {
      subdim<-round( dim( labelmask ) / mr )
      subdim[ subdim < 2*rad+1 ] <- ( 2*rad+1 )[  subdim < 2*rad+1 ]
      submask<-resampleImage( labelmask, subdim, useVoxels=1, interpType=1 )
    } else { submask = labelmask }

    ysub<-y
    xsub<-x
    nfeats<-length(xsub[[1]])

    # resample xsub and ysub
    if (mr != 1) {
      for ( i in 1:(length(xsub)) )
      {
        if ( yisimg )
          ysub[[i]]<-resampleImage( y[[i]], subdim, useVoxels=1, interpType=1 )

        xsub[[i]][[1]]<-resampleImage( xsub[[i]][[1]], subdim, useVoxels=1, 0 )
        if ( nfeats > 1 )
          for ( k in 2:nfeats )
          {
            xsub[[i]][[k]]<-resampleImage( xsub[[i]][[k]], subdim,
                                           useVoxels=1, 0 )
          }
      }
    }

    # add newprobs from previous run, already correct dimension
    if ( rfct > 1 )
    {
      for ( kk in 1:length(xsub) )
      {
        p1<-unlist( xsub[[kk]] )
        p2<-unlist(newprobs[[kk]])
        temp<-lappend(  p1 ,  p2  )
        xsub[[kk]]<-temp
      }
      rm(newprobs)
    }

    nfeats<-length(xsub[[1]])  # update nfeats with newprobs

    # build model for this mr
    sol<-vwnrfs( ysub, xsub, submask, rad, nsamples, ntrees, asFactors )



    # apply model, get chunk of probs, put chunk in masterprobs
    if (mrcount < length(multiResSchedule)) {   # not last mr, calculate probs for next cycle
      chunk.seq = seq(1, sum(submask>0), by=voxchunk)
      predtype<-'response'
      if ( asFactors ) predtype<-'prob'

      # set up probs to fill:
      masterprobs=list()
      for (tt1 in 1:length(xsub)) {
        masterprobs[[tt1]] = list()
        if (asFactors)
          nprob = length( unique( c( as.numeric( submask ) ) ) )
        else nprob=1
        for (tt2 in 1:nprob) {
          masterprobs[[tt1]][[tt2]] = submask*0
        }
      } # end creating masterprobs


      for (ch in 1:length(chunk.seq)) {

        # set end of this chunk
        if (ch < length(chunk.seq)) { chnxt=chunk.seq[ch+1]-1
        } else { chnxt=sum(submask>0) }

        # create mask for this chunk
        temp=which(submask>0, arr.ind=T)[chunk.seq[ch]:chnxt]
        nnz = submask>0 ; nnz[-temp]=F
        cropmask = submask+0
        cropmask[nnz==F] = 0

        # start filling fm
        testmat<-t(getNeighborhoodInMask( cropmask, cropmask,
                                          rad, spatial.info=F, boundary.condition='image' ))
        hdsz<-nrow(testmat) # neighborhood size
        nent<-nfeats*ncol(testmat)*nrow(testmat)*length(xsub)*1.0
        fm<-matrix( nrow=(nrow(testmat)*length(xsub)) ,
                    ncol=ncol(testmat)*nfeats  )
        rm( testmat )

        seqby<-seq.int( 1, hdsz*length(xsub)+1, by=hdsz )
        for ( i in 1:(length(xsub)) )
        {
          m1<-t(getNeighborhoodInMask( xsub[[i]][[1]], cropmask,
                                       rad, spatial.info=F, boundary.condition='image' ))
          if ( nfeats > 1 )
            for ( k in 2:nfeats )
            {
              m2<-t(getNeighborhoodInMask( xsub[[i]][[k]], cropmask,
                                           rad, spatial.info=F, boundary.condition='image' ))
              m1<-cbind( m1, m2 )
            }
          nxt<-seqby[ i + 1 ]-1
          fm[ seqby[i]:nxt, ]<-m1
        } # end filling fm, ready for predict

        probsrf<-t( predict( sol$rfm, newdata=fm, type=predtype ) )


        for ( i in 1:(length(xsub)) )
        {
          nxt<-seqby[ i + 1 ]-1
          probsx<-list(submask)
          if ( asFactors )
            probsx<-matrixToImages(probsrf[,seqby[i]:nxt],  cropmask )
          else probsx<-list( makeImage( cropmask, probsrf[,seqby[i]:nxt] ) )

          for (tt1 in 1:length(probsx)) {
               masterprobs[[i]][[tt1]][cropmask>0] = probsx[[tt1]][cropmask>0]
          }  # end filling masterprobs
        }  # end putting probs to images

        message(paste(ch,'of',length(chunk.seq)))
      } # end chunk loop, masterprobs is complete now


      # resample masterprobs back to original resolution
      newprobs=masterprobs
      if ( ! all( dim(masterprobs[[1]][[1]] ) == dim(labelmask) ) ) {
        if (mrcount < length(multiResSchedule)) {  # not last mr, resample to next mr
          nextdim = round( dim( labelmask ) / multiResSchedule[mrcount+1] )
          nextdim[ nextdim < 2*rad+1 ] <- ( 2*rad+1 )[  nextdim < 2*rad+1 ]
          for ( tt1 in 1:length(masterprobs) ) for (tt2 in 1:length(masterprobs[[tt1]]))
          {
            newprobs[[tt1]][[tt2]]<-resampleImage( masterprobs[[tt1]][[tt2]], nextdim,
                                                   useVoxels=1, 0 )
          }

        } else {  # last mr, resample to labelmask
          for ( tt1 in 1:length(masterprobs) ) for (tt2 in 1:length(masterprobs[[tt1]]))
          {
            newprobs[[tt1]][[tt2]]<-resampleImage( masterprobs[[tt1]][[tt2]], dim(labelmask),
                                           useVoxels=1, 0 )
          }
        }
      }  # end if that resamples newprobs for next level
      rm(masterprobs) ; rm(probsrf) ; rm(fm)
    }  # end if not last mr that computes newprobs


    rm(xsub) ; rm(ysub)
    rflist[[rfct]]<-sol$rfm
    rfct<-rfct+1
  } # mr loop
  return( list(rflist=rflist, randmask=sol$randmask ) )
}



