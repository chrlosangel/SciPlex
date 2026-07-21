#!/bin/bash
#SBATCH --job-name=SciPlex_FASTQ_COMBINE
#SBATCH --time=4:00:00
#SBATCH --partition=cpu
#SBATCH --cpus-per-task=1
#SBATCH --mem=20G


if command -v conda &> /dev/null; then
    echo "[INFO] Using conda environment SciPlexFlow"
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate SciPlexFlow
else
    echo "[ERROR] Conda is not installed or not in PATH. Please install Conda."
    exit 1
fi

PROJECT_DIR_DATA=$1
WORKING_DIR=$2
FASTQ_AVAILABLE=$3

echo "========== Step 1. Combine output fastq files from bcl2fastq =========="
echo "Timestamp: $(date)"
echo "[PROCESS] Combining output fastq files from bcl2fastq"
echo "[EXTERNAL] Executing SciPlex/01_COMBINE_FASTQ.sh"


# Create output directory
cd $WORKING_DIR

STEP_DIR="$WORKING_DIR/1-output-fastq-combined-runs"
echo "[INFO] Creating output directory: $STEP_DIR"
mkdir -p $STEP_DIR


FILE_LIST=$(ls ${PROJECT_DIR_DATA} | grep fastq.gz | grep R1 | grep -v Undetermined | grep -v Reports | grep -v Stats)
SAMPLE_NAMES=$(echo "${FILE_LIST}" | sed -E 's/(.*)_R[12].*/\1/' | sort | uniq)

echo "[INFO] Found samples:"
echo "${SAMPLE_NAMES}"

# Link files to output directory
# Create a directory for each sample and link the R1 and R2 files
while IFS= read -r i; do
       mkdir -p "$STEP_DIR/${i}"  # Ensure directory exists before linking files

       if [[ -f "${PROJECT_DIR_DATA}/${i}_R1.fastq.gz" ]]; then
              # Link R1 file to the output directory
              ln -sf "${PROJECT_DIR_DATA}/${i}_R1.fastq.gz" "$STEP_DIR/${i}/${i}_R1.fastq.gz"
       else
              # If R1 file is not found, print a warning message
              echo "[WARNING] ${PROJECT_DIR_DATA}/${i}_R1.fastq.gz not found."
       fi

       if [[ -f "${PROJECT_DIR_DATA}/${i}_R2.fastq.gz" ]]; then
              # Link R2 files to the output directory
              ln -sf "${PROJECT_DIR_DATA}/${i}_R2.fastq.gz" "$STEP_DIR/${i}/${i}_R2.fastq.gz"
       else
              # If R2 file is not found, print a warning message
              echo "[WARNING] ${PROJECT_DIR_DATA}/${i}_R2.fastq.gz not found."
       fi
done <<< "$SAMPLE_NAMES"

echo "[INFO] FASTQ combination process completed."