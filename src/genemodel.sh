#!/bin/bash
#SBATCH --job-name=gene_model
#SBATCH --time=20:00:00
#SBATCH --partition=cpu
#SBATCH --cpus-per-task=1
#SBATCH --mem=20G
#SBATCH --output=./PBS/gene_model_%j.out

if command -v conda &> /dev/null; then
    echo "[INFO] Using conda environment SciPlexFlow"
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate SciPlexFlow
else
    echo "[ERROR] Conda is not installed or not in PATH. Please install Conda."
    exit 1
fi

MODEL_DIR=$1
ORGANISM=$2

# [x] gene.annotations file
# [x] exon.bed
# [x] genes.bed
# [x] rRNA gene regions bed file


if [ "$ORGANISM" == "mouse" ]; then
     GENOMEDIR=$MODEL_DIR/genome/
     GFF_FILE=$GENOMEDIR/gencode.vM25.annotation.gff3
     if [ ! -f "$GFF_FILE" ]; then
          echo "GFF file $GFF_FILE does not exist. Please ensure the genome and annotation files are correctly downloaded."
          wget -P $GENOMEDIR https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M25/gencode.vM25.annotation.gff3.gz
          gunzip  $GENOMEDIR/gencode.vM25.annotation.gff3.gz 
     else
          echo "GFF file $GFF_FILE already exists. Skipping download."
     fi

     ######## Generate gene annotations file
     ANNOTATION_FILE="${MODEL_DIR}/${ORGANISM}_gene.annotations"
     awk -F'\t' '
$3 == "gene" { 
    # Extract key attributes from the 9th column
    split($9, attributes, ";"); 
    gene_name = ""; gene_id = ""; gene_type = ""; 
    for (i in attributes) {
        if (attributes[i] ~ /gene_name=/) { 
            split(attributes[i], name_parts, "="); 
            gene_name = name_parts[2]; 
        } 
        if (attributes[i] ~ /gene_id=/) { 
            split(attributes[i], id_parts, "="); 
            gene_id = id_parts[2]; 
        } 
        if (attributes[i] ~ /gene_type=/) { 
            split(attributes[i], type_parts, "="); 
            gene_type = type_parts[2]; 
        } 
    }
    if (gene_name != "" && gene_id != "") {
        print gene_name "\t" gene_id "\t" $1 "\t" $4 "\t" $5 "\t" $7 "\t" gene_type "\t" "No description"
    }
}' ${GFF_FILE} > ${ANNOTATION_FILE}

     echo "Gene annotations file created: ${ANNOTATION_FILE}"

###### Generate genes.bed file
     GENES_BED_FILE="${MODEL_DIR}/${ORGANISM}_genes.bed"

     awk -F'\t' '
$3 == "gene" {
    split($9, attributes, ";"); 
     gene_name = "";
     for (i in attributes) {
        if (attributes[i] ~ /gene_name=/) { 
            split(attributes[i], name_parts, "="); 
            gene_name = name_parts[2]; 
        } 
    }
     print $1 "\t" ($4 - 1) "\t" $5 "\t" gene_name "\t.\t" $7
}' ${GFF_FILE} > ${GENES_BED_FILE}

     sort -k1,1 -k2,2n ${GENES_BED_FILE} > ${GENES_BED_FILE}.sorted
     mv ${GENES_BED_FILE}.sorted ${GENES_BED_FILE}

     echo "Genes BED file created: ${GENES_BED_FILE}"

###### Generate exons.bed file
     EXONS_BED_FILE="${MODEL_DIR}/${ORGANISM}_exons.bed"

     awk -F'\t' '
$3 == "exon" {
    split($9, attributes, ";"); 
     exon_id = ""; gene_name = "";
     for (i in attributes) {
        if (attributes[i] ~ /exon_id=/) { 
            split(attributes[i], name_parts, "="); 
            exon_id = name_parts[2]; 
        } 
        if (attributes[i] ~ /gene_name=/) { 
           split(attributes[i], name_parts, "="); 
           gene_name = name_parts[2]; 
        }
    }
     print $1 "\t" ($4 - 1) "\t" $5 "\t" exon_id "\t.\t" $7 "\t" gene_name
}' ${GFF_FILE} > ${EXONS_BED_FILE}

     sort -k1,1 -k2,2n ${EXONS_BED_FILE} > ${EXONS_BED_FILE}.sorted
     mv ${EXONS_BED_FILE}.sorted ${EXONS_BED_FILE}
     echo "Exons BED file created: ${EXONS_BED_FILE}"

### Generate rRNA gene regions BED file
     RRNA_BED_FILE="${MODEL_DIR}/${ORGANISM}_rRNA_gene_regions.bed"

awk -F'\t' '$3 == "gene" && /gene_type=rRNA/' $GFF_FILE |\
     awk -F'\t' '{print $1 "\t" ($4 - 1) "\t" $5 "\t.\t" $7}'|\
     sort -k1,1 -k2,2n > ${RRNA_BED_FILE}

     echo "rRNA gene regions BED file created: ${RRNA_BED_FILE}"

fi

