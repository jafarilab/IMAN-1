# Required packages and datasets
library("STRINGdb")
library("igraph")
library("seqinr")
library("Biostrings")

align <- function(pattern, subject, type){
  
  p = pairwiseAlignment(pattern, subject, scoreOnly = FALSE, 
                        substitutionMatrix = substitutionMatrix, 
                        gapOpening = gapOpening, 
                        gapExtension = gapExtension)
  
  return( pid(p  , type = "PID1") )
}

combination3 <- function(L1, L2, L3) {
  
  # res1.temp <- unlist(Lists[1])
  # res2.temp <- unlist(Lists[2])
  # res3.temp <- unlist(Lists[3])
  
  res1.temp <- L1
  res2.temp <- L2
  res3.temp <- L3
  
  # combination
  x.names <- character(0)
  y.names <- character(0)
  z.names <- character(0)
  for (i in 1 : nrow(res1.temp)) {
    
    if (sum(res1.temp[i, ]) == 1) {
      vec.temp <- res2.temp[i, ] * res3.temp[(res1.temp[i,] == 1), ]
      if (sum(vec.temp) >= 1) {
        x.names <- c(x.names, rep(rownames(res1.temp)[i], sum(vec.temp)))
        y.names <- c(y.names, rep(rownames(res3.temp)[(res1.temp[i,] == 1)], sum(vec.temp)))
        z.names <- c(z.names, colnames(res3.temp)[vec.temp == 1])
      }
    }
    
    if (sum(res1.temp[i, ]) > 1) {
      list.temp <- apply(cbind(res3.temp[(res1.temp[i,] == 1), ], which(res1.temp[i,] == 1)), 1,
                         function(x) {
                           vec.temp <- res2.temp[i, ] * x[-length(x)]
                           if (sum(vec.temp) >= 1) {
                             x.names.temp <- rep(rownames(res1.temp)[i], sum(vec.temp))
                             y.names.temp <- rep(rownames(res3.temp)[x[length(x)]], sum(vec.temp))
                             z.names.temp <- colnames(res3.temp)[vec.temp == 1]
                             list(xx = x.names.temp,
                                  yy = y.names.temp,
                                  zz = z.names.temp)
                           }
                         })
      
      x.names <- c(x.names, unlist(lapply(list.temp, function(x) unlist(x[1]))))
      y.names <- c(y.names, unlist(lapply(list.temp, function(x) unlist(x[2]))))
      z.names <- c(z.names, unlist(lapply(list.temp, function(x) unlist(x[3]))))
    }
  }
  
  return(list(x.names, y.names, z.names))
}


IMAN <- function(ProteinLists, Species_IDs,   
                 identityU, substitutionMatrix, 
                 gapOpening, gapExtension, BestHit,
                 coverage, NetworkShrinkage,
                 score_threshold, STRINGversion,  
                 InputDirectory = getwd()){
  
  list_num <- length(ProteinLists)
  
  for (i in 1 : list_num) {
    if( is.character(ProteinLists[[i]]) == "FALSE" ) {
      stop(paste("Error: ProteinList", i," should be a vector of type character", sep = ""))
    }
  }

  if( !(coverage %in% 1:4) ){
    stop("Error: Coverage should be between 1 up to 4")
  }
  
  
  ## Print status
  message("Step 1/4:Downloading amino acid sequences...")
  PS_list <- list()
  for (i in 1 : list_num) {
    message(paste("Downloading amino acid sequences of List", i, sep = ""))
    PS_list <- c(PS_list, list(apply(data.frame(Protein = ProteinLists[[i]]), 1,
                 function (x) {
                   as.character(read.fasta(file =
                                             paste("http://www.uniprot.org/uniprot/",
                                                   x,".fasta",sep=""),
                                           seqtype ="AA", as.string = TRUE,
                                           set.attributes = FALSE))
                 })))
  }
  
  names(PS_list) <- c(paste("PS", seq(1 : list_num), sep = ""))

  
  message("Step 2/4: Alignment...")

  temp_list <- list()
  res_list <- list()
  for (i in 1 : (list_num - 1)) {
    for (j in (i + 1) : list_num) {
      message(paste("Align List", i," with List", j, sep = ""))
      unbinres = t(apply(as.matrix(PS_list[[i]], ncol = 1), 1, function (x) {
        apply(as.matrix(PS_list[[j]], ncol = 1), MARGIN = 1, FUN=align, x)
      }))
      res = matrix(as.numeric(unbinres > identityU), nrow(unbinres), ncol(unbinres))
      rownames(res) <- ProteinLists[[i]]
      colnames(res) <- ProteinLists[[j]]
      indx = res == 1
      temp_list = c(temp_list, list(indx * unbinres))
      res[res == 1] <- 0
      res_list <- c(res_list, list(res))
    }
  }
  
  pair_num <- list_num * (list_num - 1) / 2
  names(temp_list) <- paste("temp", seq(1 : pair_num), sep = "")
  names(res_list) <- paste("res", seq(1 : pair_num), sep = "")

  # temp_list_backup <- temp_list
  # res_list_backup <- res_list
  # 
  # temp_list <- temp_list_backup
  # res_list  <- res_list_backup
  
  if (BestHit == TRUE) {
    for (i in 1 : pair_num) {
      temp_list[[i]] <- apply(temp_list[[i]], 1, function(x) {
        ind.temp <- which(x == max(x))
        if (length(ind.temp) > 1) colnames(temp_list[[i]])[ind.temp][apply(temp_list[[i]][, ind.temp], 2, max) == x[ind.temp]]
        else colnames(temp_list[[i]])[ind.temp][max(temp_list[[i]][, ind.temp]) == x[ind.temp]]
      })
      
      for (j in 1 : length(temp_list[[i]])) {
        if (length(unlist(temp_list[[i]][j])) > 0) res_list[[i]][names(temp_list[[i]][j]), unlist(temp_list[[i]][j])] <- 1
      }
    }
  }
  if( BestHit == FALSE){
    for (i in 1 : pair_num) {
      temp_list[[i]] <- apply(temp[[i]], 1, function(x) {
        colnames(temp[[i]])[x != 0]
      })
      
      for (j in 1 : length(temp_list[[i]])) {
        if (length(unlist(temp_list[[i]][j])) > 0) res_list[[i]][names(temp_list[[i]][j]), unlist(temp_list[[i]][j])] <- 1
      }
    }
  }

  message("Step 3/4: Detection in STRING...")
  
  string_db_list <- list()
  map_list <- list()
  for (i in 1 : list_num) {
    string_db_list <- c(string_db_list, list(STRINGdb$new(version = STRINGversion, 
                                                          species= Species_IDs[[i]], 
                                                          score_threshold = score_threshold, 
                                                          input_directory = getwd())))
  }
  
  if (list_num == 4) {
    # 1-2
    x.temp1 <- rep(names(temp_list[[1]]), unlist(lapply(temp_list[[1]], length)))
    y.temp1 <- unlist(temp_list[[1]])
    # 1-3
    x.temp2 <- rep(names(temp_list[[2]]), unlist(lapply(temp_list[[2]], length)))
    z.temp1 <- unlist(temp_list[[2]])
    # 1-4
    x.temp3 <- rep(names(temp_list[[3]]), unlist(lapply(temp_list[[3]], length)))
    w.temp1 <- unlist(temp_list[[3]])
    # 2-3
    y.temp2 <- rep(names(temp_list[[4]]), unlist(lapply(temp_list[[4]], length)))
    z.temp2 <- unlist(temp_list[[4]])
    # 2-4
    y.temp3 <- rep(names(temp_list[[5]]), unlist(lapply(temp_list[[5]], length)))
    w.temp2 <- unlist(temp_list[[5]])
    # 3-4
    z.temp3 <- rep(names(temp_list[[6]]), unlist(lapply(temp_list[[6]], length)))
    w.temp3 <- unlist(temp_list[[6]])
    
    # x-y-z
    list.names1 <- combination3(res_list[[1]], res_list[[2]], res_list[[4]])
    x.names1 <- unlist(list.names1[1])
    y.names1 <- unlist(list.names1[2])
    z.names1 <- unlist(list.names1[3])
    mat.xyz1 <- cbind(x.names1, y.names1, z.names1)
    
    # x-y-w
    list.names2 <- combination3(res_list[[1]], res_list[[3]], res_list[[5]])
    x.names2 <- unlist(list.names2[1])
    y.names2 <- unlist(list.names2[2])
    w.names2 <- unlist(list.names2[3])
    mat.xyw1 <- cbind(x.names2, y.names2, w.names2)
    
    x.inters1 <- intersect(unique(x.names1), unique(x.names2))
    y.inters1 <- lapply(unique(x.inters1), function(x) {
      y.inters1 <- intersect(unique(y.names1[x.names1 == x]), unique(y.names2[x.names2 == x])) })
    
    mat.xyz2 <- matrix(NA, ncol = 3, nrow = 1)
    mat.xyw2 <- matrix(NA, ncol = 3, nrow = 1)
    for (i in 1 : length(x.inters1)) {
      mat.xyz2 <- rbind(mat.xyz2, mat.xyz1[mat.xyz1[ , 2] %in% unlist(y.inters1[i]), ])
      mat.xyw2 <- rbind(mat.xyw2, mat.xyw1[(mat.xyw1[, 1] == x.inters1[i]) & (mat.xyw1[ , 2] %in% unlist(y.inters1[i])), ])
    }
    mat.xyz2 <- mat.xyz2[-1, ]
    mat.xyw2 <- mat.xyw2[-1, ]
    
    x.inters2 <- intersect(unique(mat.xyz2[,1]), unique(unique(mat.xyw2[,1])))
    y.inters2 <- lapply(unique(x.inters2), function(x) {
      y.inters2 <- intersect(unique(mat.xyz2[mat.xyz2[,1] == x, 2]), unique(mat.xyw2[mat.xyw2[, 1] == x, 2])) })
    
    # Final lists
    mat.xyzw <- matrix(NA, nrow = 1, ncol = 4)
    for (i in 1 : length(y.inters2)) {
      for (j in 1 : length(y.inters2[[i]])) {
        z.temp <- mat.xyz2[(mat.xyz2[,1] == x.inters2[i]) & (mat.xyz2[,2] == y.inters2[[i]][j]), 3]
        w.temp <- mat.xyw2[(mat.xyw2[,1] == x.inters2[i]) & (mat.xyw2[,2] == y.inters2[[i]][j]), 3]
        res6.temp.sub <- matrix(res_list[[6]][z.temp,w.temp], ncol = length(w.temp), nrow = length(z.temp), T)
        sum.temp <- sum(res6.temp.sub)
        if (sum.temp > 0) {
          temp.mat <- matrix(NA, nrow = 1, ncol = 2)
          for (k in 1 : length(z.temp)) {
            temp.mat <- rbind(temp.mat, t(rbind(rep(z.temp[k], sum(res6.temp.sub[k,])),
                                                w.temp[res6.temp.sub[k,] == 1])))
          }
          temp.mat <- matrix(temp.mat[-1, ], ncol = 2, nrow = nrow(temp.mat) - 1)
          mat.xyzw <- rbind(mat.xyzw,
                            cbind(matrix(c(rep(x.inters2[i], sum.temp),
                                           rep(y.inters1[[i]][j], sum.temp)), ncol = 2, nrow = sum.temp),
                                  temp.mat))
        }
      }
    }
    mat.xyzw <- mat.xyzw[-1, ]
    
    
    message("Detecting List1 in STRING")
    map1 = string_db_list[[1]]$map( data.frame(UNIPROT_AC = unique(mat.xyzw[, 1])) ,
                           "UNIPROT_AC" , removeUnmappedRows = TRUE)
    if( nrow(map1) == 0 ) {
      print(ProteinLists[[1]])
      stop("Error: none of the proteins in list1 mapped to STRING ID")
    }
    
    message("Detecting List2 in STRING")
    map2 = string_db_list[[2]]$map(data.frame(UNIPROT_AC = unique(mat.xyzw[, 2])) ,
                           "UNIPROT_AC" , removeUnmappedRows = TRUE) 
    if( nrow(map2) == 0 ) {
      print(ProteinLists[[2]])
      stop("Error: none of the proteins in list2 mapped to STRING ID")
    }
    
    message("Detecting List3 in STRING")
    map3 = string_db_list[[3]]$map( data.frame(UNIPROT_AC = unique(mat.xyzw[, 3])) ,
                           "UNIPROT_AC" , removeUnmappedRows = TRUE) 
    if( nrow(map3) == 0 ) {
      print(ProteinLists[[3]])
      stop("Error: none of the proteins in list3 mapped to STRING ID")
    }
    
    message("Detecting List4 in STRING")
    map4 = string_db_list[[4]]$map( data.frame(UNIPROT_AC = unique(mat.xyzw[, 4])) ,
                           "UNIPROT_AC" , removeUnmappedRows = TRUE) 
    if( nrow(map4) == 0 ) {
      print(ProteinLists[[4]])
      stop("Error: none of the proteins in list4 mapped to STRING ID")
    }
    
    OPS = data.frame(node1 = mat.xyzw[, 1], node2 = mat.xyzw[, 2], node3 = mat.xyzw[, 3], node4 = mat.xyzw[, 4])
    OPS <- merge(OPS, map1, by.y = "UNIPROT_AC", by.x = "node1")
    colnames(OPS)[5] <- "STRING_id_1"
    OPS <- merge(OPS, map2, by.y = "UNIPROT_AC", by.x = "node2")
    colnames(OPS)[6] <- "STRING_id_2"
    OPS <- merge(OPS, map3, by.y = "UNIPROT_AC", by.x = "node3")
    colnames(OPS)[7] <- "STRING_id_3"
    OPS <- merge(OPS, map4, by.y = "UNIPROT_AC", by.x = "node4")
    colnames(OPS)[8] <- "STRING_id_4"
    
    OPS <- data.frame(node1 = OPS[, 5], node2 = OPS[, 6], node3 = OPS[, 7], node4 = OPS[, 8])
    
    OPSLabel = c()
    flag.temp <- T
    if (nrow(OPS) > 10) {OPSLabel = c(OPSLabel, paste("OPS000", c(1 : 9), sep=""))
    } else {
      OPSLabel = c(OPSLabel, paste("OPS000", c(1 : nrow(OPS)), sep=""))
      flag.temp <- F
    }
    if (nrow(OPS) > 100) {OPSLabel = c(OPSLabel, paste("OPS00", c(10 : 99), sep=""))
    } else {
      if (flag.temp) OPSLabel = c(OPSLabel, paste("OPS00", c(10 : nrow(OPS)), sep=""))
      flag.temp <- F
    }
    if (nrow(OPS) > 1000) {OPSLabel = c(OPSLabel, paste("OPS00", c(100 : 999), sep=""))
    } else {
      if (flag.temp) OPSLabel = c(OPSLabel, paste("OPS00", c(100 : nrow(OPS)), sep=""))
      flag.temp <- F
    }
    if (nrow(OPS) > 10000) {OPSLabel = c(OPSLabel, paste("OPS00", c(1000 : 9999), sep=""))
    } else {
      if (flag.temp) OPSLabel = c(OPSLabel, paste("OPS00", c(1000 : nrow(OPS)), sep=""))
      flag.temp <- F
    }
    
    OPS <- cbind(OPS, OPSLabel = OPSLabel)
    
    
    message("Step 4/4: Retrieving String Network...")
    
    message("Retrieving List1")
    Network1 = data.frame(from = string_db_list[[1]]$get_interactions(OPS$node1)$from,
                          to = string_db_list[[1]]$get_interactions(OPS$node1)$to)
    if(nrow(Network1) == 0){
      print(ProteinLists[[1]])
      stop("Error: No interaction was detected for ProteinList1")
    }
    
    message("Retrieving List2")
    Network2 = data.frame(from = string_db_list[[2]]$get_interactions(OPS$node2)$from,
                          to = string_db_list[[2]]$get_interactions(OPS$node2)$to)
    if(nrow(Network2) == 0){
      print(ProteinLists[[2]])
      stop("Error: No interaction was detected for ProteinList2")
    }
    
    message("Retrieving List3")
    Network3 = data.frame(from = string_db_list[[3]]$get_interactions(OPS$node3)$from,
                          to = string_db_list[[3]]$get_interactions(OPS$node3)$to)
    if(nrow(Network3) == 0){
      print(ProteinLists[[3]])
      stop("Error: No interaction was detected for ProteinList3")
    }
    
    message("Retrieving List4")
    Network4 = data.frame(from = string_db_list[[4]]$get_interactions(OPS$node4)$from,
                          to = string_db_list[[4]]$get_interactions(OPS$node4)$to)
    if(nrow(Network4) == 0){
      print(ProteinLists[[4]])
      stop("Error: No interaction was detected for ProteinList4")
    }
    
    message("Producing IPN...")
    
    node1 = c()
    node2 = c()
    l = nrow(OPS)
    # i = 1
    for (i in 1 : (l - 1)) {
      node.temp <- apply(OPS[c((i + 1) : l), ], 1, function(x){
        a = c(as.character(OPS[i,1]) , as.character(x[1]))
        b = c(as.character(OPS[i,2]) , as.character(x[2]))
        c = c(as.character(OPS[i,3]) , as.character(x[3]))
        d = c(as.character(OPS[i,4]) , as.character(x[4]))
        
        cond1 = ifelse(nrow(Network1[((Network1$from == a[1]) & (Network1$to) == a[2]), ]) != 0 |
                         nrow(Network1[((Network1$from == a[2]) & (Network1$to) == a[1]), ]) != 0, TRUE, FALSE)
        cond2 = ifelse(nrow(Network2[((Network2$from == b[1]) & (Network2$to) == b[2]), ]) != 0 |
                         nrow(Network2[((Network2$from == b[2]) & (Network2$to) == b[1]), ]) != 0, TRUE, FALSE)
        cond3 = ifelse(nrow(Network3[((Network3$from == c[1]) & (Network3$to) == c[2]), ]) != 0 |
                         nrow(Network3[((Network3$from == c[2]) & (Network3$to) == c[1]), ]) != 0, TRUE, FALSE)
        cond4 = ifelse(nrow(Network4[((Network4$from == d[1]) & (Network4$to) == d[2]), ]) != 0 |
                         nrow(Network4[((Network4$from == d[2]) & (Network4$to) == d[1]), ]) != 0, TRUE, FALSE)
        
        if (((cond1 + cond2 + cond3 + cond4 == 1) & (coverage == 1)) |
            ((cond1 + cond2 + cond3 + cond4 == 2) & (coverage == 2)) |
            ((cond1 + cond2 + cond3 + cond4 == 3) & (coverage == 3)) |
            ((cond1 + cond2 + cond3 + cond4 == 4) & (coverage == 4))) {
          return(c(as.character(OPS[i, 5]), as.character(x[5])))
        }
        
        if ((NetworkShrinkage == FALSE)) {
          t1 = as.character(OPS[i, 1]) == as.character(x[1])
          t2 = as.character(OPS[i, 2]) == as.character(x[2])
          t3 = as.character(OPS[i, 3]) == as.character(x[3])
          t4 = as.character(OPS[i, 4]) == as.character(x[4])
          
          mycond = cond1 + cond2 + cond3 + cond4
          TT = t1 + t2 + t3 + t4
          if (TT + mycond >= coverage){
            return(c(as.character(OPS[i, 5]), as.character(x[5])))
          }
          
        }
      })
      
      if (! is.null(node.temp)) {
        node1 <- c(node1, unlist(node.temp)[seq(1, length(unlist(node.temp)), 2)])
        node2 <- c(node2, unlist(node.temp)[seq(2, length(unlist(node.temp)), 2)])
      }
    }
    
    EdgeList = data.frame(node1 , node2)  #, node3, node4)
    
    map_list <- list(map1, map2, map3, map4)
    network_list <- list(Network1, Network2, Network3, Network4)
  }
  if (list_num == 3) {
    # 1-2
    x.temp1 <- rep(names(temp_list[[1]]), unlist(lapply(temp_list[[1]], length)))
    y.temp1 <- unlist(temp_list[[1]])
    # 1-3
    x.temp2 <- rep(names(temp_list[[2]]), unlist(lapply(temp_list[[2]], length)))
    z.temp1 <- unlist(temp_list[[2]])
    # 2-3
    y.temp2 <- rep(names(temp_list[[3]]), unlist(lapply(temp_list[[3]], length)))
    z.temp2 <- unlist(temp_list[[3]])
    
    # combination
    x.names <- character(0)
    y.names <- character(0)
    z.names <- character(0)
    for (i in 1 : nrow(res_list[[1]])) {
      
      if (sum(res_list[[1]][i, ]) == 1) {
        vec.temp <- res_list[[2]][i, ] * res_list[[3]][(res_list[[1]][i,] == 1), ]
        if (sum(vec.temp) >= 1) {
          x.names <- c(x.names, rep(rownames(res_list[[1]])[i], sum(vec.temp)))
          y.names <- c(y.names, rep(rownames(res_list[[3]])[(res_list[[1]][i,] == 1)], sum(vec.temp)))
          z.names <- c(z.names, colnames(res_list[[3]])[vec.temp == 1])
        }
      }
      
      if (sum(res_list[[1]][i, ]) > 1) {
        list.temp <- apply(cbind(res_list[[3]][(res_list[[1]][i,] == 1), ], which(res_list[[1]][i,] == 1)), 1,
                           function(x) {
                             vec.temp <- res_list[[2]][i, ] * x[-length(x)]
                             if (sum(vec.temp) >= 1) {
                               x.names.temp <- rep(rownames(res_list[[1]])[i], sum(vec.temp))
                               y.names.temp <- rep(rownames(res_list[[3]])[x[length(x)]], sum(vec.temp))
                               z.names.temp <- colnames(res_list[[3]])[vec.temp == 1]
                               list(xx = x.names.temp,
                                    yy = y.names.temp,
                                    zz = z.names.temp)
                             }
                           })
        
        x.names <- c(x.names, unlist(lapply(list.temp, function(x) unlist(x[1]))))
        y.names <- c(y.names, unlist(lapply(list.temp, function(x) unlist(x[2]))))
        z.names <- c(z.names, unlist(lapply(list.temp, function(x) unlist(x[3]))))
      }
    }
    
    
    message("Detecting List1 in STRING")
    
    map1 = string_db_list[[1]]$map( data.frame(UNIPROT_AC = unique(x.names)) ,
                           "UNIPROT_AC" , removeUnmappedRows = TRUE)
    
    
    if( nrow(map1) == 0 ) {
      stop("Error: none of the proteins in list1 mapped to STRING ID")
    }
    
    
    message("Detecting List2 in STRING")
    
    map2 = string_db_list[[2]]$map( data.frame(UNIPROT_AC = unique(y.names)) ,
                           "UNIPROT_AC" , removeUnmappedRows = TRUE) 
    
    if( nrow(map2) == 0 ) {
      stop("Error: none of the proteins in list2 mapped to STRING ID")
    }
    
    
    message("Detecting List3 in STRING")
    
    map3 = string_db_list[[3]]$map(data.frame(UNIPROT_AC = unique(z.names)) ,
                           "UNIPROT_AC" , removeUnmappedRows = TRUE) 
    
    if( nrow(map3) == 0 ) {
      stop("Error: none of the proteins in list3 mapped to STRING ID")
    }
    
    OPS = data.frame(node1 = x.names, node2 = y.names, node3 = z.names)
    OPS <- merge(OPS, map1, by.y = "UNIPROT_AC", by.x = "node1")
    colnames(OPS)[4] <- "STRING_id_1"
    OPS <- merge(OPS, map2, by.y = "UNIPROT_AC", by.x = "node2")
    colnames(OPS)[5] <- "STRING_id_2"
    OPS <- merge(OPS, map3, by.y = "UNIPROT_AC", by.x = "node3")
    colnames(OPS)[6] <- "STRING_id_3"
    
    OPS <- data.frame(node1 = OPS[, 4], node2 = OPS[, 5], node3 = OPS[, 6])
    
    OPSLabel = c()
    flag.temp <- T
    if (nrow(OPS) > 10) {OPSLabel = c(OPSLabel,paste("OPS000", c(1 : 9), sep=""))
    } else {
      OPSLabel = c(OPSLabel,paste("OPS000", c(1 : nrow(OPS)), sep=""))
      flag.temp <- F
    }
    if (nrow(OPS) > 100) {OPSLabel = c(OPSLabel,paste("OPS00", c(10 : 99), sep=""))
    } else {
      if (flag.temp) OPSLabel = c(OPSLabel,paste("OPS00", c(10 : nrow(OPS)), sep=""))
      flag.temp <- F
    }
    if (nrow(OPS) > 1000) {OPSLabel = c(OPSLabel,paste("OPS00", c(100 : 999), sep=""))
    } else {
      if (flag.temp) OPSLabel = c(OPSLabel,paste("OPS00", c(100 : nrow(OPS)), sep=""))
      flag.temp <- F
    }
    if (nrow(OPS) > 10000) {OPSLabel = c(OPSLabel,paste("OPS00", c(1000 : 9999), sep=""))
    } else {
      if (flag.temp) OPSLabel = c(OPSLabel,paste("OPS00", c(1000 : nrow(OPS)), sep=""))
      flag.temp <- F
    }
    
    OPS <- cbind(OPS, OPSLabel = OPSLabel)
    
    
    message("Step 4/4: Retrieving String Network...")
    
    message("Retrieving List1")
    Network1 = data.frame(from = string_db_list[[1]]$get_interactions(OPS$node1)$from,
                          to = string_db_list[[1]]$get_interactions(OPS$node1)$to)
    if(nrow(Network1) == 0){
      print(ProteinLists[[1]])
      stop("Error: No interaction was detected for ProteinList1")
    }
    
    message("Retrieving List2")
    Network2 = data.frame(from = string_db_list[[2]]$get_interactions(OPS$node2)$from,
                          to = string_db_list[[2]]$get_interactions(OPS$node2)$to)
    if(nrow(Network2) == 0){
      print(ProteinLists[[2]])
      stop("Error: No interaction was detected for ProteinList2")
    }
    
    message("Retrieving List3")
    Network3 = data.frame(from = string_db_list[[3]]$get_interactions(OPS$node3)$from,
                          to = string_db_list[[3]]$get_interactions(OPS$node3)$to)
    if(nrow(Network3) == 0){
      print(ProteinLists[[3]])
      stop("Error: No interaction was detected for ProteinList3")
    }
    
    
    message("Producing IPN...")
    
    node1 = c()
    node2 = c()
    l = nrow(OPS)
    
    # i = 1
    for (i in 1 : (l - 1)) {
      node.temp <- apply(OPS[c((i + 1) : l), ], 1, function(x){
        a = c(as.character(OPS[i,1]) , as.character(x[1]))
        b = c(as.character(OPS[i,2]) , as.character(x[2]))
        c = c(as.character(OPS[i,3]) , as.character(x[3]))
        
        cond1 = ifelse(nrow(Network1[((Network1$from == a[1]) & (Network1$to) == a[2]), ]) != 0 |
                         nrow(Network1[((Network1$from == a[2]) & (Network1$to) == a[1]), ]) != 0, TRUE, FALSE)
        cond2 = ifelse(nrow(Network2[((Network2$from == b[1]) & (Network2$to) == b[2]), ]) != 0 |
                         nrow(Network2[((Network2$from == b[2]) & (Network2$to) == b[1]), ]) != 0, TRUE, FALSE)
        cond3 = ifelse(nrow(Network3[((Network3$from == c[1]) & (Network3$to) == c[2]), ]) != 0 |
                         nrow(Network3[((Network3$from == c[2]) & (Network3$to) == c[1]), ]) != 0, TRUE, FALSE)
        
        if (((cond1 + cond2 + cond3 == 1) & (coverage == 1)) |
            ((cond1 + cond2 + cond3 == 2) & (coverage == 2)) |
            ((cond1 + cond2 + cond3 == 3) & (coverage ==3))) {
          return(c(as.character(OPS[i,4]), as.character(x[4])))
        }
        
        if ((NetworkShrinkage == FALSE)) {
          t1 = as.character(OPS[i,1]) == as.character(x[1])
          t2 = as.character(OPS[i,2]) == as.character(x[2])
          t3 = as.character(OPS[i,3]) == as.character(x[3])
          
          mycond = cond1 + cond2 + cond3
          TT = t1 + t2 + t3
          if (TT+mycond >= coverage){
            return(c(as.character(OPS[i,4]), as.character(x[4])))
          }
          
        }
      })
      
      if (! is.null(node.temp)) {
        node1 <- c(node1, unlist(node.temp)[seq(1, length(unlist(node.temp)), 2)])
        node2 <- c(node2, unlist(node.temp)[seq(2, length(unlist(node.temp)), 2)])
      }
    }
    
    EdgeList = data.frame(node1 , node2) #, node3)
    
    map_list <- list(map1, map2, map3)
    network_list <- list(Network1, Network2, Network3)
  }
  if (list_num == 2) {
    x <- rep(names(temp_list[[1]]), unlist(lapply(temp_list[[1]], length)))
    xperim = unlist(temp_list[[1]])
    
    message("Detecting List1 in STRING")
    map1 = string_db_list[[1]]$map(data.frame(UNIPROT_AC = unique(x)) ,
                           "UNIPROT_AC" , removeUnmappedRows = TRUE)
    
    if ( nrow(map1) == 0 ) {
      stop("Error: none of the proteins in list1 mapped to STRING ID")
    }
    
    message("Detecting List2 in STRING")
    map2 = string_db_list[[2]]$map( data.frame(UNIPROT_AC = unique(xperim)) ,
                           "UNIPROT_AC" , removeUnmappedRows = TRUE) 
    
    if (nrow(map2) == 0) {
      stop("Error: none of the proteins in list2 mapped to STRING ID")
    }
    
    OPS = data.frame(node1 = x, node2 = xperim)
    OPS <- merge(OPS, map1, by.y = "UNIPROT_AC", by.x = "node1")
    colnames(OPS)[3] <- "STRING_id_1"
    OPS <- merge(OPS, map2, by.y = "UNIPROT_AC", by.x = "node2")
    colnames(OPS)[4] <- "STRING_id_2"
    
    OPS <- data.frame(node1 = OPS[, 3], node2 = OPS[, 4])
    
    OPSLabel = c()
    flag.temp <- T
    if (nrow(OPS) > 10) {OPSLabel = c(OPSLabel, paste("OPS000", c(1 : 9), sep=""))
    } else {
      OPSLabel = c(OPSLabel,paste("OPS000", c(1 : nrow(OPS)), sep=""))
      flag.temp <- F
    }
    if (nrow(OPS) > 100) {OPSLabel = c(OPSLabel, paste("OPS00", c(10 : 99), sep=""))
    } else {
      if (flag.temp) OPSLabel = c(OPSLabel, paste("OPS00", c(10 : nrow(OPS)), sep=""))
      flag.temp <- F
    }
    if (nrow(OPS) > 1000) {OPSLabel = c(OPSLabel, paste("OPS00", c(100 : 999), sep=""))
    } else {
      if (flag.temp) OPSLabel = c(OPSLabel,paste("OPS00", c(100 : nrow(OPS)), sep=""))
      flag.temp <- F
    }
    if (nrow(OPS) > 10000) {OPSLabel = c(OPSLabel,paste("OPS00", c(1000 : 9999), sep=""))
    } else {
      if (flag.temp) OPSLabel = c(OPSLabel,paste("OPS00", c(1000 : nrow(OPS)), sep=""))
      flag.temp <- F
    }
    
    OPS <- cbind(OPS, OPSLabel = OPSLabel)
    
    message("Step 4/4: Retrieving String Network...")
    
    message("Retrieving List1")
    Network1 = data.frame(from = string_db_list[[1]]$get_interactions(OPS$node1)$from,
                          to = string_db_list[[1]]$get_interactions(OPS$node1)$to)
    
    if (nrow(Network1) == 0) {
      print(ProteinLists[[1]])
      stop("Error: No STRING network was detected for ProteinList1")
    }
    
    message("Retrieving List2")
    Network2 = data.frame(from = string_db_list[[2]]$get_interactions(OPS$node2)$from,
                          to = string_db_list[[2]]$get_interactions(OPS$node2)$to)
    
    if (nrow(Network2) == 0) {
      print(ProteinLists[[2]])
      stop("Error: No STRING network was detected for ProteinList2")
    }
    
    message("Producing IPN...")
    
    node1 = c()
    node2 = c()
    l = nrow(OPS)
    
    # i = 1
    for (i in 1 : (l - 1)) {
      node.temp <- apply(OPS[c((i + 1) : l), ], 1, function(x){
        a = c(as.character(OPS[i,1]) , as.character(x[1]))
        b = c(as.character(OPS[i,2]) , as.character(x[2]))
        
        cond1 = ifelse(nrow(Network1[((Network1$from == a[1]) & (Network1$to) == a[2]), ]) != 0 |
                         nrow(Network1[((Network1$from == a[2]) & (Network1$to) == a[1]), ]) != 0, TRUE, FALSE)
        cond2 = ifelse(nrow(Network2[((Network2$from == b[1]) & (Network2$to) == b[2]), ]) != 0 |
                         nrow(Network2[((Network2$from == b[2]) & (Network2$to) == b[1]), ]) != 0, TRUE, FALSE)
        
        if (((cond1+cond2 == 1) & (coverage == 1)) | ((cond1+cond2 == 2) & (coverage == 2))) {
          return(c(as.character(OPS[i,3]), as.character(x[3])))
        }
        
        if ((NetworkShrinkage == FALSE)) {
          t1 = as.character(OPS[i,1]) == as.character(x[1])
          t2 = as.character(OPS[i,2]) == as.character(x[2])
          
          mycond = cond1 + cond2 
          TT = t1 + t2 
          if (TT+mycond >= coverage){
            return(c(as.character(OPS[i,3]), as.character(x[3])))
          }
          
        }
      })
      
      if (! is.null(node.temp)) {
        node1 <- c(node1, unlist(node.temp)[seq(1, length(unlist(node.temp)), 2)])
        node2 <- c(node2, unlist(node.temp)[seq(2, length(unlist(node.temp)), 2)])
      }
    }

    EdgeList = data.frame(node1 , node2)
    
    map_list <- list(map1, map2)
    network_list <- list(Network1, Network2)
  }
  
  
  if (nrow(EdgeList) != 0) {
    IPN = graph_from_data_frame(d = EdgeList, directed = FALSE)
    reslist = list(IPNEdges = EdgeList , IPNNodes = OPS, 
                   Networks = network_list,
                   maps = map_list)
    plot(IPN)
    message("DONE!")
    return(reslist)
  }
  
  if (nrow(EdgeList) == 0) {
    reslist = list(IPNEdges = EdgeList , IPNNodes = OPS, 
                   Networks = network_list,
                   maps = map_list)
    message("DONE! But EdgeList is empty!")
    return(reslist)
  }
}

 