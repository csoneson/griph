if(getRversion() >= "2.15.1")  utils::globalVariables(c("i")) # let codetools know about "i" in foreach()

# Fast, memory efficient computation of Pearson's correlation for big matrices using BLAS implementations, parallelization and bigmemory objects 
# In a 16core machine with R' BLAS implementeation a 10Kx10K input matrix is processed in ~5' (~10x speed-up over the built-in impementation). 
# More optimized BLAS versions (ATLAS, openBLAS) should offer further improvements.
# Input is a matrix and the desired number of cores
FlashPearsonCor <- function (DM,ncores="all") { 

  DM=as.big.matrix(DM)
  desc<-describe(DM)
  NCOL=desc@description["totalCols"][[1]]

  ncores=getDoParWorkers()
  nblocks = ncores 

  corMAT <- matrix(data=0,nrow=NCOL,ncol=NCOL )
  corMAT <- as.big.matrix(corMAT,type="double")
  bigCOR <- describe(corMAT)
  ## split column numbers into 'nblocks' groups and create all unique combinations of blocks
  SPLIT=split(1:NCOL, ceiling(seq_along(1:NCOL)/ceiling(NCOL/nblocks)  ))
  COMBS <- expand.grid(1:length(SPLIT), 1:length(SPLIT))
  COMBS <- t(apply(COMBS, 1, sort))
  
  COMBS <- unique(COMBS)
  
  ## iterate through each block combination, calculate correlation matrix between blocks and store them:
  results<-foreach(i = 1:nrow(COMBS),.export=c('pcor'), .packages=('bigmemory') ) %dopar%{
    COMB <- COMBS[i, ]
    G1 <- SPLIT[[COMB[1]]]
    G2 <- SPLIT[[COMB[2]]]
    DM<-attach.big.matrix(desc)
    corMAT<-attach.big.matrix(bigCOR)
    
    if(COMB[1]==COMB[2] || nrow(COMBS)< 20) {
      v=unique(c(G1,G2))
      COR <- pcor(as.matrix(DM[,v]))
      corMAT[v, v] <- COR
    }
    else{
      COR <- cor(as.matrix(DM[,G1]), as.matrix(DM[,G2]))
      corMAT[G1,G2]=COR
      corMAT[G2,G1]=t(COR)
    }
    
    COR <- NULL
    return(0L)
  }
  return(as.matrix(corMAT))
}




# Fast, memory efficient computation of Shrinked Correlation Estimates for big matrices using BLAS implementations, parallelization and bigmemory objects 
# More optimized BLAS versions (ATLAS, openBLAS) should offer further improvements.
# Input is a matrix, the desired number of cores and the lambda parameter controlling shrinkage intensity
FlashShrinkCor <- function (DM,ncores="all",lambda=0, w=rep(1,nrow(DM)),verbose=FALSE ) { 
  
  DM=as.big.matrix(DM)
  desc<-describe(DM)
  NCOL=desc@description["totalCols"][[1]]

  ncores=getDoParWorkers()
  nblocks = ncores 

  corMAT <- matrix(data=0,nrow=NCOL,ncol=NCOL)
  corMAT <- as.big.matrix(corMAT,type="double")
  bigCOR <- describe(corMAT)
  ## split column numbers into 'nblocks' groups and create all unique combinations of blocks
  SPLIT=split(1:NCOL, ceiling(seq_along(1:NCOL)/ceiling(NCOL/nblocks)  ))
  COMBS <- expand.grid(1:length(SPLIT), 1:length(SPLIT))
  COMBS <- t(apply(COMBS, 1, sort))
  if (nrow(COMBS)>1) {COMBS <- COMBS[-which(COMBS[,1]==COMBS[,2]),]}
  COMBS <- unique(COMBS)
  
  ## iterate through each block combination, calculate correlation matrix between blocks and store them:
  results<-foreach(i = 1:nrow(COMBS),.export=c('cor.shrink'), .packages=('bigmemory') ) %dopar%{
    COMB <- COMBS[i, ]
    G1 <- SPLIT[[COMB[1]]]
    G2 <- SPLIT[[COMB[2]]]
    x<-attach.big.matrix(desc)
    corMAT<-attach.big.matrix(bigCOR)
    v=unique(c(G1,G2))
    COR <- cor.shrink(x[,v],verbose=verbose,lambda=lambda,w=w)
    corMAT[v, v] <- COR
    COR <- NULL
    return(0L)
  }
  return(as.matrix(corMAT))
}




# Fast, memory efficient computation of Spearman's correlation for big matrices using BLAS implementations, parallelization and bigmemory objects 
# In a 16core machine with R' BLAS implementeation a 10Kx10K input matrix is processed in ~5' (~10x speed-up over the built-in impementation). 
# More optimized BLAS versions (ATLAS, openBLAS) should offer further improvements.
# Input is a matrix and the desired number of cores
FlashSpearmanCor <- function (DM,ncores="all") { 
  
  DM=as.big.matrix(DM)
  desc<-describe(DM)
  NCOL=desc@description["totalCols"][[1]]
  NROW=desc@description["totalRows"][[1]]

  ncores=getDoParWorkers()
  nblocks = ncores 
  corMAT <- matrix(data=0,nrow=NCOL,ncol=NCOL )
  corMAT <- as.big.matrix(corMAT,type="double")
  bigCOR <-  describe(corMAT)
  RankMAT <- matrix(data=0,nrow=NROW,ncol=NCOL )
  RankMAT <- as.big.matrix(RankMAT,type="double")
  bigRank <- describe(RankMAT)
  
  ## split column numbers into 'nblocks' groups and create all unique combinations of blocks
  SPLIT=split(1:NCOL, ceiling(seq_along(1:NCOL)/ceiling(NCOL/nblocks)  ))
  COMBS <- expand.grid(1:length(SPLIT), 1:length(SPLIT))
  COMBS <- t(apply(COMBS, 1, sort))
  COMBS <- unique(COMBS)
  
  ## iterate through each block and fill the rank matrix:
  results<-foreach(i = 1:length(SPLIT), .packages=('bigmemory') ) %dopar%{
    M<-attach.big.matrix(desc)
    RankMAT<-attach.big.matrix(bigRank)
    RANK=vapply( SPLIT[[i]],function (x) rank(M[,x]),FUN.VALUE =( double(length=nrow(M) ))  )
    RankMAT[,SPLIT[[i]]]=RANK
    RANK <- NULL
    return(0L)
  }
  
  ## iterate through each block combination, calculate correlation matrix between blocks and store them:
  results<-foreach(i = 1:nrow(COMBS),.export=c('pcor'), .packages=('bigmemory') ) %dopar%{
    COMB <- COMBS[i, ]
    G1 <- SPLIT[[COMB[1]]]
    G2 <- SPLIT[[COMB[2]]]
    RankMAT<-attach.big.matrix(bigRank)
    corMAT<-attach.big.matrix(bigCOR)
    
    if(COMB[1]==COMB[2] || nrow(COMBS)< 20) {
      v=unique(c(G1,G2))
      COR <- pcor(as.matrix(RankMAT[,v]))
      corMAT[v, v] <- COR
    }
    else{
      COR <- cor(as.matrix(RankMAT[,G1]), as.matrix(RankMAT[,G2]))
      corMAT[G1,G2]=COR
      corMAT[G2,G1]=t(COR)
    }
    COR <- NULL
    return(0L)
  }
  return(as.matrix(corMAT))
}




# Fast, memory efficient computation of canberra distance using  parallelization and bigmemory objects 
# Input is a matrix and the desired number of cores
FlashCanberra <- function (DM,ncores="all") { 

  DM=as.big.matrix(DM)
  desc<-describe(DM)
  NCOL=desc@description["totalCols"][[1]]
  NROW=desc@description["totalRows"][[1]]

  ncores=getDoParWorkers()
  nblocks = ncores 

  distMAT <- matrix(data=0,nrow=NCOL,ncol=NCOL )
  distMAT <- as.big.matrix(distMAT,type="double")
  bigDIST <-  describe(distMAT)
  ## split column numbers into 'nblocks' groups and create all unique combinations of blocks
  SPLIT=split(1:NCOL, ceiling(seq_along(1:NCOL)/ceiling(NCOL/nblocks)  ))
  COMBS <- expand.grid(1:length(SPLIT), 1:length(SPLIT))
  COMBS <- t(apply(COMBS, 1, sort))
  if (nrow(COMBS)>1) {COMBS <- COMBS[-which(COMBS[,1]==COMBS[,2]),]}
  COMBS <- unique(COMBS)
  ## iterate through each block combination, calculate correlation matrix between blocks and store them:
  results<-foreach(i = 1:nrow(COMBS), .packages=('bigmemory') ) %dopar%{
    COMB <- COMBS[i, ]
    G1 <- SPLIT[[COMB[1]]]
    G2 <- SPLIT[[COMB[2]]]
    x<-attach.big.matrix(desc)
    distMAT<-attach.big.matrix(bigDIST)
    v=unique(c(G1,G2))
    DIST <- as.matrix(dist(t(x[,v]),method="canberra" ))
    distMAT[v, v] <- DIST
    DIST <- NULL
    return(0L)
  }
  return(as.matrix(distMAT))
}




# Fast, memory efficient computation of Hellinger distance using  parallelization and bigmemory objects 
# Input is a matrix and the desired number of cores
FlashHellinger <- function (DM,ncores="all") {
  DM=as.big.matrix(DM)
  desc<-describe(DM)
  NCOL=desc@description["totalCols"][[1]]
  NROW=desc@description["totalRows"][[1]]
  
  ncores=getDoParWorkers()
  nblocks = ncores 

  distMAT <- matrix(data=0,nrow=NCOL,ncol=NCOL )
  distMAT <- as.big.matrix(distMAT,type="double")
  bigDIST <-  describe(distMAT)
  ## split column numbers into 'nblocks' groups and create all unique combinations of blocks
  SPLIT=split(1:NCOL, ceiling(seq_along(1:NCOL)/ceiling(NCOL/nblocks)  ))
  COMBS <- expand.grid(1:length(SPLIT), 1:length(SPLIT))
  COMBS <- t(apply(COMBS, 1, sort))
  if (nrow(COMBS)>1) {COMBS <- COMBS[-which(COMBS[,1]==COMBS[,2]),]}
  COMBS <- unique(COMBS)
  ## iterate through each block combination, calculate correlation matrix between blocks and store them:
  results<-foreach(i = 1:nrow(COMBS), .export=c('HellingerMat'),.packages=('bigmemory') ) %dopar%{
    COMB <- COMBS[i, ]
    G1 <- SPLIT[[COMB[1]]]
    G2 <- SPLIT[[COMB[2]]]
    x<-attach.big.matrix(desc)
    distMAT<-attach.big.matrix(bigDIST)
    v=unique(c(G1,G2))
    DIST<-HellingerMat(x[,v])
    distMAT[v, v] <- DIST
    DIST <- NULL
    return(0L)
  }
  return(as.matrix(distMAT))
}




# Parallel regularized estimates of the inverse covarinace matrix using the QUIC implementation.
FlashGlasso <- function (DM,ncores="all",rho=0.3,tol=1e-3,maxIter=100,msg=0) { 

  DM=as.big.matrix(DM)
  desc<-describe(DM)
  NCOL=desc@description["totalCols"][[1]]
  NROW=desc@description["totalRows"][[1]]
  
  if (!is.matrix(rho) && length(rho) != 1 && length(rho) !=NCOL)  {  stop("Wrong number of elements in rho") }
  if (is.vector(rho)) { rho <- matrix(sqrt(rho)) %*% sqrt(rho) }
  if (length(rho) == 1) {rho <- matrix(rho, ncol = NCOL, nrow = NCOL)}
  
  ncores=getDoParWorkers()
  nblocks = ncores 

  PrecMAT <- matrix(data=0,nrow=NCOL,ncol=NCOL )
  PrecMAT <- as.big.matrix(PrecMAT,type="double")
  bigPREC <- describe(PrecMAT)
  ## split column numbers into 'nblocks' groups and create all unique combinations of blocks
  SPLIT=split(1:NCOL, ceiling(seq_along(1:NCOL)/ceiling(NCOL/nblocks)  ))
  COMBS <- expand.grid(1:length(SPLIT), 1:length(SPLIT))
  COMBS <- t(apply(COMBS, 1, sort))
  if (nrow(COMBS)>1) {COMBS <- COMBS[-which(COMBS[,1]==COMBS[,2]),]}
  COMBS <- unique(COMBS)
  
  ## iterate through each block combination, calculate sparse inv. cov. matrix between blocks and store them:
  results<-foreach(i = 1:nrow(COMBS),.export=c('QUIC'), .packages=('bigmemory') ) %dopar%{
    COMB <- COMBS[i, ]
    G1 <- SPLIT[[COMB[1]]]
    G2 <- SPLIT[[COMB[2]]]
    x<-attach.big.matrix(desc)
    PrecMAT<-attach.big.matrix(bigPREC)
    v=unique(c(G1,G2))
    r=rho[v,v]
    PREC <- QUIC(x[v,v],rho=r,maxIter=maxIter,tol=tol,msg=msg)$X
    PrecMAT[v, v] <- PREC
    PREC <- NULL
    return(0L)
  }
  return(as.matrix(PrecMAT))
}




#Parallel regularized non-negative matrix factorization
FlashRNMF <- function (DM,ncores="all",k=6,alpha = 0.15,tol=1e-2,maxit=10,showprogress=FALSE,quiet=TRUE) { 
  DM=as.big.matrix(DM)
  desc<-describe(DM)
  NCOL=desc@description["totalCols"][[1]]
  NROW=desc@description["totalRows"][[1]]
  
  ncores=getDoParWorkers()
  nblocks = ncores 

  DMimp <- matrix(data=0,nrow=NROW,ncol=NCOL )
  DMimp <- as.big.matrix(DMimp,type="double")
  bigDMimp <- describe(DMimp)
  ## split column numbers into 'nblocks' groups
  SPLIT=split(1:NCOL, ceiling(seq_along(1:NCOL)/ceiling(NCOL/nblocks)  ))

  ## iterate through each block and apply rNMF:
  results<-foreach(i = 1:length(SPLIT),.export=c('rnmf'), .packages=('bigmemory') ) %dopar%{
    G <- SPLIT[[i]]
    x<-attach.big.matrix(desc)
    DMimp<-attach.big.matrix(bigDMimp)
    IMP <- rnmf(x[,G],k=k,alpha = alpha,tol=tol,maxit=maxit,showprogress=showprogress,quiet=quiet)$fit
    DMimp[, G] <- IMP
    IMP <- NULL
    return(0L)
  }
  return(as.matrix(DMimp))
}




#Parallel computation of personalized-pagerank based distances
FlashPPR <- function (G,ncores="all",df=0.75) { 
  if (!isTRUE(is.igraph(G))) {  
    if (!isSymmetric(G) )  {stop ("!! G should be either a graph object or a symmetric matrix !!")}   
    G=igraph::graph.adjacency(G [1:nrow(G),1:nrow(G)],mode=c("max"),weighted=TRUE,diag=FALSE)
  }
  
  NCOL=length(V(G))

  L=length(V(G))
  ncores=getDoParWorkers()
  nblocks = ncores 

  PR=diag(nrow=L)
  ## split column numbers into 'nblocks' groups and create all unique combinations of blocks
  SPLIT=split(1:L, ceiling(seq_along(1:L)/ceiling(L/nblocks)  ))
  ## iterate through each block combination, calculate kernel distance between blocks and store them:
  results<-foreach(i = 1:length(SPLIT),.export=c('page_rank'),.combine='c' ) %dopar%{
    vids=SPLIT[[i]]
    vals=sapply(vids, function(x) page_rank(G, vids=c(1:L),personalized=PR[,x],damping=df )$vector   )
    vals=log2(unlist(vals)+(0.01/L))
  }
  PR[1:length(PR)]=results
  PR[lower.tri(PR)]=(PR[lower.tri(PR)]+t(PR)[lower.tri(t(PR))])/2
  PR[upper.tri(PR)]=t(PR)[upper.tri(t(PR))]
  PR=2^PR
  return(PR)
}


