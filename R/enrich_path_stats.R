### Over-representation analysis using hypergeometric tests
### The probability is calculated from obtaining the equal or higher number
### of hits using 1-phyper. Since phyper is a cumulative probability,
### to get P(X>=hit.num) => P(X>(hit.num-1))

#'Calculate ORA score
#'@description Calculate the over representation analysis score
#'@usage CalculateOraScore(mSetObj=NA, nodeImp, method)
#'@param mSetObj Input the name of the created mSetObj (see InitDataObjects)
#'@param nodeImp Indicate the pathway topology analysis, "rbc" for relative-betweeness centrality, 
#'and "dgr" for out-degree centrality. 
#'@param method is "fisher" or "hyperg"
#'@author Jeff Xia \email{jeff.xia@mcgill.ca}
#'McGill University, Canada
#'License: GNU GPL (>= 2)
#'@export

CalculateOraScore <- function(mSetObj=NA, nodeImp, method){
  
  mSetObj <- .get.mSet(mSetObj);

  # make a clean dataSet$cmpd data based on name mapping
  # only valid kegg id will be used
  
  nm.map <- GetFinalNameMap(mSetObj);
  
  if(mSetObj$pathwaylibtype == "KEGG"){
    valid.inx <- !(is.na(nm.map$kegg)| duplicated(nm.map$kegg));
    ora.vec <- nm.map$kegg[valid.inx];
  } else if(mSetObj$pathwaylibtype == "SMPDB"){
    valid.inx <- !(is.na(nm.map$hmdbid)| duplicated(nm.map$hmdbid));
    ora.vec <- nm.map$hmdbid[valid.inx];
  }
  q.size<-length(ora.vec);
  
  if(is.na(ora.vec) || q.size==0) {
    if(mSetObj$pathwaylibtype == "KEGG"){
      AddErrMsg("No valid KEGG compounds found!");
    } else if(mSetObj$pathwaylibtype == "SMPDB"){
      AddErrMsg("No valid SMPDB compounds found!");
    }
    return(0);
  }
  
  current.mset <- metpa$mset.list;
  uniq.count <- metpa$uniq.count;
  
  # check if need to be filtered against reference metabolome
  # TODO: address the following filtering for SMPDB if needed
  if(mSetObj$dataSet$use.metabo.filter && !is.null(mSetObj$dataSet$metabo.filter.kegg)){
    current.mset <- lapply(current.mset, function(x){x[x %in% mSetObj$dataSet$metabo.filter.kegg]});
    mSetObj$analSet$ora.filtered.mset <- current.mset;
    uniq.count <- length(unique(unlist(current.mset, use.names=FALSE)));
  }
  
  hits <- lapply(current.mset, function(x){x[x %in% ora.vec]});
  hit.num <-unlist(lapply(hits, function(x){length(x)}), use.names=FALSE);
  set.size <-length(current.mset);
  set.num <- unlist(lapply(current.mset, length), use.names=FALSE);
  
  # prepare for the result table
  res.mat<-matrix(0, nrow=set.size, ncol=8);
  rownames(res.mat)<-names(current.mset);
  colnames(res.mat)<-c("Total", "Expected", "Hits", "Raw p", "-log(p)", "Holm adjust", "FDR", "Impact");
  
  if(nodeImp == "rbc"){
    imp.list <- metpa$rbc;
    mSetObj$msgSet$topo.msg <- "Your selected node importance measure for topological analysis is \\textbf{relative betweenness centrality}.";
  }else{
    imp.list <- metpa$dgr;
    mSetObj$msgSet$topo.msg <- "Your selected node importance measure for topological analysis is \\textbf{out degree centrality}.";
  }
  
  res.mat[,1]<-set.num;
  res.mat[,2]<-q.size*(set.num/uniq.count);
  res.mat[,3]<-hit.num;
  
  if(method == "fisher"){
    res.mat[,4] <- GetFisherPvalue(hit.num, q.size, set.num, uniq.count);
    mSetObj$msgSet$rich.msg <- "The selected over-representation analysis method is \\textbf{Fishers' exact test}.";
  }else{
    # use lower.tail = F for P(X>x)
    res.mat[,4] <- phyper(hit.num-1, set.num, uniq.count-set.num, q.size, lower.tail=F);
    mSetObj$msgSet$rich.msg <- "The selected over-representation analysis method is \\textbf{Hypergeometric test}.";
  }
  
  res.mat[,5] <- -log(res.mat[,4]);
  
  # adjust for multiple testing problems
  res.mat[,6] <- p.adjust(res.mat[,4], "holm");
  res.mat[,7] <- p.adjust(res.mat[,4], "fdr");
  # calculate the sum of importance
  res.mat[,8] <- mapply(function(x, y){sum(x[y])}, imp.list, hits);
  
  res.mat <- res.mat[hit.num>0, , drop=FALSE];
  res.mat <- res.mat[!is.na(res.mat[,8]), , drop=FALSE];
  
  if(nrow(res.mat) > 1){
    ord.inx <- order(res.mat[,4], res.mat[,8]);
    res.mat <- res.mat[ord.inx,];
  }
  
  mSetObj$analSet$ora.mat <- signif(res.mat,5);
  mSetObj$analSet$ora.hits <- hits;
  mSetObj$analSet$node.imp <- nodeImp;
  
  .set.mSet(mSetObj)
  
  save.mat <- mSetObj$analSet$ora.mat;
  rownames(save.mat) <- GetORA.pathNames(mSetObj);
  write.csv(save.mat, file="pathway_results.csv");
  
  if(.on.public.web){
    return(1);
  }else{
    return(.set.mSet(mSetObj));
  }
}

#'Export pathway names from ORA analysis
#'@param mSetObj Input the name of the created mSetObj (see InitDataObjects)
#'@export
GetORA.pathNames <- function(mSetObj=NA){
  mSetObj <- .get.mSet(mSetObj);
  hit.inx <- match(rownames(mSetObj$analSet$ora.mat), metpa$path.ids);
  return(names(metpa$path.ids)[hit.inx]);
}

#'Calculate quantitative enrichment score
#'@description Calculate quantitative enrichment score
#'@usage CalculateQeaScore(mSetObj=NA, nodeImp, method)
#'@param mSetObj Input the name of the created mSetObj (see InitDataObjects)
#'@param nodeImp Indicate the pathway topology analysis, "rbc" for relative-betweeness centrality, 
#'and "dgr" for out-degree centrality. 
#'@param method Indicate the pathway enrichment analysis, global test is "gt" and global ancova is "ga".
#'@author Jeff Xia \email{jeff.xia@mcgill.ca}
#'McGill University, Canada
#'License: GNU GPL (>= 2)
#'@export

CalculateQeaScore <- function(mSetObj=NA, nodeImp, method){
  
  mSetObj <- .get.mSet(mSetObj);
  
  # first, need to make a clean dataSet$norm data based on name mapping
  # only contain valid kegg id will be used
  nm.map <- GetFinalNameMap(mSetObj);
  
  if(mSetObj$pathwaylibtype == "KEGG"){
    valid.inx <- !(is.na(nm.map$kegg)| duplicated(nm.map$kegg));
  } else if(mSetObj$pathwaylibtype == "SMPDB"){
    valid.inx <- !(is.na(nm.map$hmdbid)| duplicated(nm.map$hmdbid));
  }
  nm.map <- nm.map[valid.inx,];
  orig.nms <- nm.map$query;
  
  kegg.inx <- match(colnames(mSetObj$dataSet$norm),orig.nms);
  hit.inx <- !is.na(kegg.inx);
  path.data<-mSetObj$dataSet$norm[,hit.inx];

  if(mSetObj$pathwaylibtype == "KEGG"){
    colnames(path.data) <- nm.map$kegg[kegg.inx[hit.inx]];
  } else if(mSetObj$pathwaylibtype == "SMPDB"){
    colnames(path.data) <- nm.map$hmdbid[kegg.inx[hit.inx]];
  }

  # calculate univariate p values when click indivisual compound node
  # use lm model for t-tests (with var.equal=T), one-way anova, and linear regression (continuous);
  univ.p <- apply(as.matrix(path.data), 2, function(x) {
    tmp <- try(lm(as.numeric(mSetObj$dataSet$cls)~x));
    if(class(tmp) == "try-error") {
      return(NA);
    }else{
      tmp<-anova(tmp)
      return(tmp[1,5]);
    }
  });
  
  names(univ.p) <- colnames(path.data);
  
  # now, perform topology & enrichment analysis
  current.mset <- metpa$mset.list;
  uniq.count <- metpa$uniq.count;
  
  # check if a reference metabolome is applied
  if(mSetObj$dataSet$use.metabo.filter && !is.null(mSetObj$dataSet[["metabo.filter.kegg"]])){
    current.mset<-lapply(current.mset, function(x) {x[x %in% mSetObj$dataSet$metabo.filter.kegg]});
    mSetObj$analSet$qea.filtered.mset <- current.mset;
    uniq.count <- length(unique(unlist(current.mset), use.names=FALSE));
  }
  
  hits <- lapply(current.mset, function(x) {x[x %in% colnames(path.data)]});
  hit.inx <- unlist(lapply(hits, function(x) {length(x)}), use.names=FALSE) > 0;
  hits <- hits[hit.inx]; # remove no hits

  # store data before microservice
  mSetObj$analSet$qea.univp <- signif(univ.p,7);
  mSetObj$analSet$node.imp <- nodeImp;
  mSetObj$dataSet$norm.path <- path.data;
  mSetObj$analSet$qea.hits <- hits;
  mSetObj$analSet$qea.method <- method;

  # calculate the impact values
  if(nodeImp == "rbc"){
    imp.list <- metpa$rbc[hit.inx];
    mSetObj$msgSet$topo.msg <- "Your selected node importance measure for topological analysis is \\textbf{relative betweenness centrality}.";
  }else{
    imp.list <- metpa$dgr[hit.inx];
    mSetObj$msgSet$topo.msg <- "Your selected node importance measure for topological analysis is \\textbf{out degree centrality}.";
  }
  imp.vec <- mapply(function(x, y){sum(x[y])}, imp.list, hits);
  set.num<-unlist(lapply(current.mset[hit.inx], length), use.names=FALSE);
  
  if(method == "gt"){
    mSetObj$msgSet$rich.msg <- "The selected pathway enrichment analysis method is \\textbf{Globaltest}.";
    if(.on.public.web){ # this is done by R microservice
        gt.in <- list(cls=mSetObj$dataSet$cls, data=path.data, subsets=hits, set.num=set.num, imp.vec=imp.vec);
        saveRDS(gt.in, "gt_in.rds");
        return(.set.mSet(mSetObj));
    }    
    qea.obj <- globaltest::gt(mSetObj$dataSet$cls, path.data, subsets=hits);
    qea.res <- globaltest::result(qea.obj);
    match.num <- qea.res[,5];
    raw.p <- qea.res[,1];
  }else{
    qea.obj <- NULL;
    mSetObj$msgSet$rich.msg <- "The selected pathway enrichment analysis method is \\textbf{GlobalAncova}.";
    if(.on.public.web){ # this is done by R microservice
        ga.in <- list(data=path.data, group=mSetObj$dataSet$cls, test.genes=hits, set.num=set.num, imp.vec=imp.vec);
        saveRDS(ga.in, "ga_in.rds");
        return(.set.mSet(mSetObj));
    } 
    qea.res <- GlobalAncova::GlobalAncova(xx=t(path.data), group=mSetObj$dataSet$cls, test.genes=hits, method="approx");
    match.num <- qea.res[,1];
    raw.p <- qea.res[,3];
  }
  
  log.p <- -log(raw.p);
  # add adjust p values
  holm.p <- p.adjust(raw.p, "holm");
  fdr.p <- p.adjust(raw.p, "fdr");
  
  res.mat <- cbind(set.num, match.num, raw.p, log.p, holm.p, fdr.p, imp.vec);
  rownames(res.mat)<-rownames(qea.res);
  colnames(res.mat)<-c("Total Cmpd", "Hits", "Raw p", "-log(p)", "Holm adjust", "FDR", "Impact");
  res.mat <- res.mat[!is.na(res.mat[,7]), , drop=FALSE];
  
  ord.inx<-order(res.mat[,3], -res.mat[,7]);
  res.mat<-signif(res.mat[ord.inx,],5);

  hit.inx <- match(rownames(res.mat), metpa$path.ids);
  pathNames <- names(metpa$path.ids)[hit.inx];
  rownames(res.mat) <- pathNames;
  write.csv(res.mat, file="pathway_results.csv");

  mSetObj$analSet$qea.mat <- res.mat;
  mSetObj$analSet$qea.pathNames <- pathNames;
  return(.set.mSet(mSetObj)); 
}

#'Export pathway names from QEA analysis
#'@param mSetObj Input the name of the created mSetObj (see InitDataObjects)
#'@export
GetQEA.pathNames <- function(mSetObj=NA){
  mSetObj <- .get.mSet(mSetObj);
  return(mSetObj$analSet$qea.pathNames);
}

#'Only works for human (hsa.rda) data
#'@description Only works for human (hsa.rda) data
#'2018 - works for ath, eco, mmu, sce
#'@param kegg.ids Input the list of KEGG ids to add SMPDB links
#'@author Jeff Xia \email{jeff.xia@mcgill.ca}
#'McGill University, Canada
#'License: GNU GPL (>= 2)
#'@export
#'
SetupSMPDBLinks <- function(kegg.ids){
  smpdb.vec <- names(metpa$path.smps)[match(kegg.ids,metpa$path.smps)]
  lk.len <- length(smpdb.vec);
  all.lks <- vector(mode="character", length=lk.len);
  for(i in 1:lk.len){
    lks <- strsplit(smpdb.vec[i], "; ")[[1]];
    if(!is.na(lks[1])){
      all.lks[i]<-paste("<a href=http://www.smpdb.ca/view/",lks," target=_new>SMP</a>", sep="", collapse="\n");
    }
  }
  return(all.lks);
}

#'Only works for human (hsa.rda) data
#'@description Only works for human (hsa.rda) data
#'2018 - works for ath, eco, mmu, sce
#'@param kegg.ids Input the list of KEGG ids to add SMPDB links
#'@author Jeff Xia \email{jeff.xia@mcgill.ca}
#'McGill University, Canada
#'License: GNU GPL (>= 2)
#'@export
#'
SetupKEGGLinks <- function(smpdb.ids){
  kegg.vec <- metpa$path.keggs[match(smpdb.ids,names(metpa$mset.list))]
  lk.len <- length(kegg.vec);
  all.lks <- vector(mode="character", length=lk.len);
  for(i in 1:lk.len){
    lks <- strsplit(kegg.vec[i], "; ")[[1]];
    if(!is.na(lks[1])){
      all.lks[i] <- paste("<a href=http://www.genome.jp/kegg-bin/show_pathway?",lks," target=_new>KEGG</a>", sep="");
      # all.lks[i]<-paste("<a href=http://pathman.smpdb.ca/pathways/",lks,"/pathway target=_new>SMP</a>", sep="", collapse="\n");
    }
  }
  return(all.lks);
}

##############################################
##############################################
########## Utilities for web-server ##########
##############################################
##############################################

#'Given a metset inx, return hmtl highlighted pathway cmpds
#'@description Given a metset inx, return hmtl highlighted pathway cmpds
#'@param mSetObj Input the name of the created mSetObj (see InitDataObjects)
#'@param msetNm Input the name of the metabolite set
#'@author Jeff Xia \email{jeff.xia@mcgill.ca}
#'McGill University, Canada
#'License: GNU GPL (>= 2)
#'@export
#'
GetHTMLPathSet <- function(mSetObj=NA, msetNm){
  mSetObj <- .get.mSet(mSetObj);
  pathid <- metpa$path.ids[msetNm]; 
  mset <- metpa$mset.list[[pathid]];
  
  hits <- NULL;
  if(mSetObj$analSet$type=="pathora"){
    hits <- mSetObj$analSet$ora.hits;
  }else{
    hits <- mSetObj$analSet$qea.hits;
  }
  
  # highlighting with different colors
  red.inx <- which(mset %in% hits[[pathid]]);
  
  # use actual cmpd names
  nms <- names(mset);
  nms[red.inx] <- paste("<font color=\"red\">", "<b>", nms[red.inx], "</b>", "</font>",sep="");
  return(cbind(msetNm, paste(nms, collapse="; ")));
}

GetORA.keggIDs <- function(mSetObj=NA){
  mSetObj <- .get.mSet(mSetObj);
  if(mSetObj$pathwaylibtype == "KEGG"){
    kegg.vec <- rownames(mSetObj$analSet$ora.mat);
    kegg.vec <- paste("<a href=http://www.genome.jp/kegg-bin/show_pathway?",kegg.vec," target=_new>KEGG</a>", sep="");
  } else{ # pathwaylibtype == "HMDB"
    return(SetupKEGGLinks(rownames(mSetObj$analSet$ora.mat)));
  }
  return(kegg.vec);
}

#'Only for human pathways (SMPDB)
#'@description Only for human pathways + ath, eco, mmu & sce
#'@param mSetObj Input the name of the created mSetObj (see InitDataObjects)
#'@author Jeff Xia \email{jeff.xia@mcgill.ca}
#'McGill University, Canada
#'License: GNU GPL (>= 2)
GetORA.smpdbIDs <- function(mSetObj=NA){
  mSetObj <- .get.mSet(mSetObj);
  if(mSetObj$pathwaylibtype == "KEGG"){
    return(SetupSMPDBLinks(rownames(mSetObj$analSet$ora.mat)));
  } else{
    hmdb.vec <- rownames(mSetObj$analSet$ora.mat);
    all.lks <-paste("<a href=http://www.smpdb.ca/view/",hmdb.vec," target=_new>SMP</a>", sep="");
    return(all.lks)
  }
}

#'Only for human pathways (KEGG)
#'@description Only for human pathways + ath, eco, mmu & sce
#'@param mSetObj Input the name of the created mSetObj (see InitDataObjects)
#'@author Jeff Xia \email{jeff.xia@mcgill.ca}
#'McGill University, Canada
#'License: GNU GPL (>= 2)
GetQEA.keggIDs <- function(mSetObj=NA){
  mSetObj <- .get.mSet(mSetObj);
  if(mSetObj$pathwaylibtype == "KEGG"){
    kegg.vec <- rownames(mSetObj$analSet$qea.mat);
    kegg.vec <- paste("<a href=http://www.genome.jp/kegg-bin/show_pathway?",kegg.vec," target=_new>KEGG</a>", sep="");
  } else{ # pathwaylibtype == "HMDB"
    return(SetupKEGGLinks(rownames(mSetObj$analSet$qea.mat)));
  }
  return(kegg.vec);
}

GetQEA.smpdbIDs <- function(mSetObj=NA){
  mSetObj <- .get.mSet(mSetObj);
  if(mSetObj$pathwaylibtype == "KEGG"){
    return(SetupSMPDBLinks(rownames(mSetObj$analSet$qea.mat)));
  } else{
    hmdb.vec <- rownames(mSetObj$analSet$qea.mat);
    all.lks <-paste("<a href=http://www.smpdb.ca/view/",hmdb.vec," target=_new>SMP</a>", sep="");
    return(all.lks)
  }
}