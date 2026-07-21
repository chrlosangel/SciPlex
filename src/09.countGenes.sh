#!/bin/bash

#SBATCH --job-name=SciPlex_Assign_Reads_To_Genes
#SBATCH --partition=cpu
#SBATCH --time=10:00:00
#SBATCH --mem=30G
#SBATCH --nodes=1

STEP_8_DIR=$1
SAMPLE=$2
GENE_BED=$3
EXON_BED=$4
PYTHON_SCRIPT=$5
STEP_DIR=$6

if command -v conda &> /dev/null; then
    echo "[INFO] Using conda environment SciPlexFlow"
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate SciPlexFlow
else
    echo "[ERROR] Conda is not installed or not in PATH. Please install Conda."
    exit 1
fi


echo "========== Step 9. =========="
echo "Timestamp: $(date)"
echo "[PROCESS]  Split reads in BAM files into BED intervals..."
echo "[EXTERNAL] Executing SciPlex/src/09.countGenes.sh"


bedtools map \
    -a $STEP_8_DIR/$SAMPLE.bed \
    -b $EXON_BED \
    -nonamecheck -s -f 0.95 -c 7 -o distinct -delim '|' \
| bedtools map \
    -a - -b $GENE_BED \
    -nonamecheck -s -f 0.95 -c 4 -o distinct -delim '|' \
| sort -k4,4 -k2,2n -k3,3n -S 3G \
| datamash \
    -g 4 first 1 first 2 last 3 first 5 first 6 collapse 7 collapse 8 \
| $PYTHON_SCRIPT $GENE_BED \
> $STEP_DIR/$SAMPLE.txt


