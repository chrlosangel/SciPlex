#!/bin/bash

#SBATCH --job-name=SciPlex_STAR_Alignment
#SBATCH --partition=cpu
#SBATCH --time=40:00:00
#SBATCH --mem=30G
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4

if command -v conda &> /dev/null; then
    echo "[INFO] Using conda environment SciPlexFlow"
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate SciPlexFlow
else
    echo "[ERROR] Conda is not installed or not in PATH. Please install Conda."
    exit 1
fi

STEP_4_DIR=$1
SAMPLE=$2
STAR_INDEX=$3
STEP_DIR=$4



echo "========== Step 5. STAR Alignment =========="
echo "Timestamp: $(date)"
echo "[PROCESS]  STAR Alignment..."
echo "[EXTERNAL] Executing SciPlex/src/05.star.sh"

SAMPLE="${SAMPLE}_trimmed.fq.gz"

STAR \
    --runThreadN 4 \
    --genomeDir ${STAR_INDEX} \
    --genomeLoad NoSharedMemory \
    --readFilesIn ${STEP_4_DIR}/${SAMPLE} \
    --readFilesCommand zcat \
    --outFileNamePrefix ${STEP_DIR}/${SAMPLE}. \
    --outSAMtype BAM Unsorted \
    --outSAMstrandField intronMotif



