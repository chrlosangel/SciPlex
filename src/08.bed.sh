#!/bin/bash

#SBATCH --job-name=SciPlex_makeBED
#SBATCH --partition=cpu
#SBATCH --time=10:00:00
#SBATCH --mem=10G
#SBATCH --nodes=1

if command -v conda &> /dev/null; then
    echo "[INFO] Using conda environment SciPlexFlow"
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate SciPlexFlow
else
    echo "[ERROR] Conda is not installed or not in PATH. Please install Conda."
    exit 1
fi


STEP_6_DIR=$1
SAMPLE=$2
STEP_DIR=$3
AWK8=$4



echo "========== Step 8. Split reads in BAM files into BED intervals =========="
echo "Timestamp: $(date)"
echo "[PROCESS]  Split reads in BAM files into BED intervals..."
echo "[EXTERNAL] Executing SciPlex/08_MAKE_BED.sh"

samtools view -h $STEP_6_DIR/$SAMPLE.bam \
    | awk -f $AWK8 \
    | samtools view -bh \
    | bedtools bamtobed -i - -split \
    | sort -k1,1 -k2,2n -k3,3n -S 3G \
    > $STEP_DIR/$SAMPLE.bed
