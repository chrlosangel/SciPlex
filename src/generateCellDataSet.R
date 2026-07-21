#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(dplyr)
    library(scales)
    library(ggplot2)
    library(reshape2)
    library(stringr)
    library(monocle3)
    library(data.table) 
    library(Matrix)
})


args = commandArgs(trailingOnly = T)

mat.path = args[1]
gene.annotation.path = args[2]
cell.annotation.path = args[3]
output.dir = args[4]

load.cds = function(mat.path, gene.annotation.path, cell.annotation.path){
    # Read the UMI matrix
    umi_df = fread(mat.path,sep = "\t", header = FALSE, col.names = c('gene.idx', 'cell.idx', 'umi.count'))
    setDF(umi_df)	
    # Read the gene annotations
    gene.annotation = fread(gene.annotation.path, col.names = c('chr', 'start', 'end', 'gene.name', 'x', 'strand'))
    setDF(gene.annotation)  # Convert to data.frame 
    colnames(gene.annotation)[colnames(gene.annotation) == "gene.name"] = "gene_short_name"
    rownames(gene.annotation) = gene.annotation$gene_short_name
    # Read the cell annotations
    cell.annotation = fread(cell.annotation.path, sep = "\t", header = FALSE, col.names = c('RT_Ligation', 'Well_Barcodes'))
    setDF(cell.annotation)
    rownames(cell.annotation) = cell.annotation$Well_Barcodes  # Ensure cell names exist
    
    
    

	#When constructing the sparse matrix, the function ensures that every gene appears at least once.
	#If a gene is not expressed in any real cell, it would be dropped from the sparse matrix.
    df = rbind(umi_df, data.frame(
        gene.idx = c(1, nrow(gene.annotation)),
        cell.idx = rep(nrow(cell.annotation)+1, 2),
        umi.count = c(1, 1)))
	mat = sparseMatrix(i = df$gene.idx, j = df$cell.idx, x = df$umi.count)

	cat("# of genes:", nrow(gene.annotation), "\n")
	cat("# of cells:", ncol(mat), "\n")
	#Each (gene, cell) pair should have the correct UMI count:
	#any(duplicated(df[, c("gene.idx", "cell.idx")]))
	#[1] FALSE
	# most likely the problem is not coming from duplicated (gene, cell) pairs

	mat = mat[, 1:(ncol(mat)-1)] 
	print(paste("Dimensions of the matrix:", dim(mat)))
	print(paste("Number of non-zero values:", nnzero(mat)))
	print(paste("Possible number of non-zero values:", prod(dim(mat))))
	sparsity = (1 - (nnzero(mat) / prod(dim(mat)))) * 100
	print(paste("Sparsity:", sparsity, "%"))

	cds = new_cell_data_set(mat, cell_metadata = cell.annotation, gene_metadata = gene.annotation)
     colData(cds)$n.umi = Matrix::colSums(exprs(cds))

    	return(cds)
	
	#which(mat != 0, arr.ind = TRUE) #if we want to see the non-zero values
	#nnzero(mat) 
	#[1] 39720500 we have 39720500 non-zero values so we are good there

    #return(list(umi_df = umi_df, gene.annotation = gene.annotation, cell.annotation = cell.annotation))
}
cds = load.cds(mat.path,gene.annotation.path,cell.annotation.path)

saveRDS(object = cds,
    file = paste(output.dir, "/", "CellDataSet_precell_prehash.RDS", sep = ""))
#We have a CellDataSet object now that is ready to be used for clustering
#mat is the sparse matrix of the UMI counts
#cell.annotation is the cell annotations
#gene.annotation is the gene annotations
#mat the object is basically genes x cells matrix of UMI counts and then transformed into a CellDataSet object




