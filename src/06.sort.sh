#!/bin/bash

#SBATCH --job-name=SciPlex_SortAndFilter
#SBATCH --partition=cpu
#SBATCH --time=40:00:00
#SBATCH --mem=30G
#SBATCH --cpus-per-task=4
#SBATCH --nodes=1

if command -v conda &> /dev/null; then
    echo "[INFO] Using conda environment SciPlexFlow"
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate SciPlexFlow
else
    echo "[ERROR] Conda is not installed or not in PATH. Please install Conda."
    exit 1
fi

STEP_5_DIR=$1
SAMPLE=$2
STEP_DIR=$3

echo "========== Step 6. BAM Sort And Filter -q 30 -F4 =========="
echo "Timestamp: $(date)"
echo "[PROCESS]  SAM Sort..."
echo "[EXTERNAL] Executing SciPlex/src/06.sort.sh"

FILE=$SAMPLE"_trimmed.fq.gz.Aligned.out.bam"

    
samtools view -bh -q 30 -F 4 $STEP_5_DIR/$FILE \
    | samtools sort -@ 4 - > $STEP_DIR/$SAMPLE.bam
echo "Processed $FILE"
