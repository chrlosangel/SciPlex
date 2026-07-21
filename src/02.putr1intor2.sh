#!/bin/bash
#SBATCH --job-name=SciPlex_R1toR2
#SBATCH --time=15:00:00
#SBATCH --partition=cpu
#SBATCH --cpus-per-task=1
#SBATCH --mem=30G

if command -v conda &> /dev/null; then
    echo "[INFO] Using conda environment SciPlexFlow"
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate SciPlexFlow
else
    echo "[ERROR] Conda is not installed or not in PATH. Please install Conda."
    exit 1
fi

FASTQ_DIR_STEP1=$1   # directory containing sample subdirectories
SAMPLE_NAME=$2       # single sample name (e.g. A01B01)
RT_BARCODES_FILE=$3
LIG_BARCODES_FILE=$4
INDEXING_KEY=$5
STEP_DIR=$6          # output directory
AWK_SCRIPT=$7

echo "========== Step 2. Put read 1 information (RT well, UMI) into read 2 =========="
echo "Timestamp: $(date)"
echo "[INFO] Sample: $SAMPLE_NAME"
echo "[INFO] FASTQ directory: $FASTQ_DIR_STEP1"
echo "[INFO] RT oligo list: $RT_BARCODES_FILE"
echo "[INFO] Ligation oligo list: $LIG_BARCODES_FILE"
echo "[INFO] Indexing key: $INDEXING_KEY"
echo "----------------------------------------------"

R1_FILE="${FASTQ_DIR_STEP1}/${SAMPLE_NAME}/${SAMPLE_NAME}_R1.fastq.gz"
R2_FILE="${FASTQ_DIR_STEP1}/${SAMPLE_NAME}/${SAMPLE_NAME}_R2.fastq.gz"

R1_FILE=$(readlink -f "${R1_FILE}")
R2_FILE=$(readlink -f "${R2_FILE}")

echo "[INFO] R1 file: ${R1_FILE}"
echo "[INFO] R2 file: ${R2_FILE}"
echo "----------------------------------------------"

PCR_COMBO="$SAMPLE_NAME"

paste <(gunzip -c "${R1_FILE}") <(gunzip -c "${R2_FILE}") | \
    awk -v PCR_COMBO="${PCR_COMBO}" -f "${AWK_SCRIPT}" \
        "${RT_BARCODES_FILE}" "${LIG_BARCODES_FILE}" "${INDEXING_KEY}" - | \
    gzip > "${STEP_DIR}/${PCR_COMBO}.fastq.gz"

echo "[INFO] Done processing sample: ${SAMPLE_NAME}"
echo "----------------------------------------------"
