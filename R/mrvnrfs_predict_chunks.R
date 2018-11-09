#' multi-res voxelwise neighborhood random forest segmentation
#'
#' Represents multiscale feature images as a neighborhood and uses the features
#' to apply a random forest segmentation model to a new image
#'
#' @param rflist a list of random forest models from mrvnrfs
#' @param x a list of lists where each list contains feature images
#' @param labelmask a mask for the features (all in the same image space)
#' @param rad vector of dimensionality d define nhood radius
#' @param multiResSchedule an integer vector defining multi-res levels
#' @param asFactors boolean - treat the y entries as factors
#' @return list a 4-list with the rf model, training vector, feature matrix
#' and the random mask
#' @param verbose print diagnostic messages
#' @param voxchunk value of maximal voxels to predict at once.
#' This value is used to split the prediction into smaller chunks
#' such that memory requirements do not become too big
#' @author Avants BB, Tustison NJ, Pustina D
#'
#' @export
#' @importFrom ANTsRCore lappend makeImage matrixToImages
#' @importFrom ANTsRCore getNeighborhoodInMask imageListToMatrix
#' @importFrom ANTsR splitMask
#' @importFrom stats predict
#' @import randomForest
#'
linda_mrvnrfs.predict_chunks <- function(
  rflist, x, labelmask, rad=NA,
  multiResSchedule=c(4,2,1), asFactors=TRUE,
  voxchunk=1000,
  verbose = TRUE) {
  rfct<-1
  newprobs = NULL

  for ( mr in multiResSchedule )
  {
    subdim<-round( dim( labelmask ) / mr )
    subdim[ subdim < 2*rad+1 ] <- ( 2*rad+1 )[  subdim < 2*rad+1 ]
    submask<-resampleImage( labelmask, subdim, useVoxels=1,
                            interpType=1 )
    xsub<-x
    if ( rfct > 1 )
    {
      for ( kk in 1:length(xsub) )
      {
        temp<-lappend(  unlist( xsub[[kk]] ) ,  unlist(newprobs[[kk]])  )
        xsub[[kk]]<-temp
      }
    }
    nfeats<-length(xsub[[1]])


    # just resample xsub
    for ( i in 1:(length(xsub)) )
    {
      xsub[[i]][[1]]<-resampleImage( xsub[[i]][[1]], subdim, useVoxels=1, 0 )
      # xsub[[i]][[1]] = resampleImageToTarget(
      #   image = xsub[[i]][[1]],
      #   target = submask,
      #   interpType = "linear")
      if ( nfeats > 1 )
        for ( k in 2:nfeats )
        {
          xsub[[i]][[k]]<-resampleImage( xsub[[i]][[k]], subdim,
                                         useVoxels=1, 0 )
          # xsub[[i]][[k]] = resampleImageToTarget(
          #   image = xsub[[i]][[k]],
          #   target = submask,
          #   interpType = "linear")
        }
    }


    predtype<-'response'
    if ( asFactors ) predtype<-'prob'

    # apply model, get probs, feed them to next level
    chunk.seq = seq(1, sum(submask>0), by=voxchunk)

    # set up probs to fill, get number of labels from model
    masterprobs=list()
    for (tt1 in 1:length(xsub)) {
      masterprobs[[tt1]] = list()
      if (asFactors) {
        nprob = length(levels(rflist[[1]]$y)) + 1
        #         nprob = length( unique( c( as.numeric( submask ) ) ) )
      } else { nprob=1 }
      for (tt2 in 1:nprob) {
        masterprobs[[tt1]][[tt2]] = submask*0
      }
    } # end creating masterprobs


    chunkmask = splitMask(submask, voxchunk = voxchunk)


    for (ch in 1:max(chunkmask)) {

      # # set end of this chunk # removed block after ANTsR reconfig in July 2017
      # if (ch < length(chunk.seq)) { chnxt=chunk.seq[ch+1]-1
      # } else { chnxt=sum(submask>0) }
      #
      # # create mask for this chunk
      # temp=which(submask>0)[chunk.seq[ch]:chnxt]
      # nnz = submask>0 ; nnz[-temp]=F
      # cropmask = submask+0
      # cropmask[nnz==F] = 0

      cropmask = thresholdImage(chunkmask, ch, ch)

      # print_msg("Neighborhood for mask", verbose = verbose)

      # start filling fm
      testmat<-t(getNeighborhoodInMask( cropmask, cropmask,
                                        rad, spatial.info=FALSE,
                                        boundary.condition='image' ))
      hdsz<-nrow(testmat) # neighborhood size
      nent<-nfeats*ncol(testmat)*nrow(testmat)*length(xsub)*1.0
      fm<-matrix( nrow=(nrow(testmat)*length(xsub)) ,
                  ncol=ncol(testmat)*nfeats  )
      rm( testmat )

      # print_msg("Neighborhood info from features", verbose = verbose)

      seqby<-seq.int( 1, hdsz*length(xsub)+1, by=hdsz )
      for ( i in 1:(length(xsub)) )
      {
        m1<-t(getNeighborhoodInMask(
          xsub[[i]][[1]], cropmask,
          rad, spatial.info=FALSE,
          boundary.condition='image' ))
        if ( nfeats > 1 )
          for ( k in 2:nfeats )
          {
            m2<-t(getNeighborhoodInMask(
              xsub[[i]][[k]], cropmask,
              rad, spatial.info=FALSE,
              boundary.condition='image' ))
            m1<-cbind( m1, m2 )
          }
        nxt<-seqby[ i + 1 ]-1
        fm[ seqby[i]:nxt, ]<-m1
      } # end filling fm, ready for predict

      # print_msg("Predicting from RF", verbose = verbose)

      probs<-t( predict( rflist[[rfct]] ,newdata=fm, type=predtype) )

      for ( i in 1:(length(xsub)) )
      {
        nxt<-seqby[ i + 1 ]-1
        probsx<-list(submask)
        if ( asFactors ) {
          probsx<-matrixToImages(probs[,seqby[i]:nxt],  cropmask )
        } else { probsx<-list( makeImage( cropmask, probs[,seqby[i]:nxt] ) )  }


        for (tt1 in 1:length(probsx)) {
          masterprobs[[i]][[tt1]][cropmask>0] = probsx[[tt1]][cropmask>0]
        }  # end filling masterprobs
      }  # end putting probs to images


      # resample masterprobs back to original resolution
      newprobs=masterprobs
      if ( ! all( dim(masterprobs[[1]][[1]] ) == dim(labelmask) ) )
      {
        for ( tt1 in 1:length(masterprobs) ) for (tt2 in 1:length(masterprobs[[tt1]]))
        {
          newprobs[[tt1]][[tt2]]<-resampleImage(
            masterprobs[[tt1]][[tt2]], dim(labelmask),
            useVoxels=1, 0 )
          # newprobs[[tt1]][[tt2]] = resampleImageToTarget(
          #   masterprobs[[tt1]][[tt2]],
          #   target = labelmask,
          #   interpType = "linear")
        }
      }
      if (verbose) {
        message(paste(ch,'of',length(chunk.seq)))
      }
    }  # end chunk loop
    rm(masterprobs)
    rfct<-rfct+1
    # print(rfct)
  } # mr loop

  # prediction is finished, create segmentation
  if ( asFactors )
  {
    # print_msg("Making Segmentations", verbose = verbose)

    rfseg=list()
    for (segno in 1:length(newprobs)) {
      rfseg[[segno]]<-imageListToMatrix( unlist(newprobs[[segno]]) , labelmask )
      rfseg[[segno]]<-apply( rfseg[[segno]], FUN=which.max, MARGIN=2)
      rfseg[[segno]]<-makeImage( labelmask , rfseg[[segno]] )
    }
    return( list( seg=rfseg, probs=newprobs ) )
  }
  print_msg("Setting equal to median", verbose = verbose)

  rfseg<-apply( imageListToMatrix( unlist(newprobs) ,
                                   labelmask ), FUN=median, MARGIN=1 )
  return( list( seg=rfseg, probs=newprobs ) )
}
