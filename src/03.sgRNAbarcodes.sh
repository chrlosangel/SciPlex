#!/bin/bash
#SBATCH --job-name=SciPlex_Crop_sgRNAs
#SBATCH --time=15:00:00
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


STEP_DIR_2=$1 # "$FASTQ_DIR_STEP1" \
SAMPLE=$2 #$SAMPLE
SGRNA_BARCODES_FILE=$3 #$SGRNA_BARCODES_FILE
STEP_DIR=$4  #$OUTPUT_DIR or $STEP_DIR" \
STEP_3_AWK=$5 #"$SCRIPTS_DIR" \

echo "========== Step 3.  Parsing sgRNAs =========="
echo "Timestamp: $(date)"
echo "[PROCESS]  Parsing sgRNAs"
echo "[EXTERNAL] Executing SciPlex/03_sgRNA_BARCODES.sh"

FILE="$STEP_DIR_2/${SAMPLE}.fastq.gz" #already combined
PCR_COMBO=$SAMPLE
echo "[INFO] Demux file: ${FILE}"
zcat ${FILE} | awk -f "${STEP_3_AWK}" "${SGRNA_BARCODES_FILE}" - | \
sed -e 's/|/,/g' | awk 'BEGIN {FS=","; OFS="\t";} {print $2,$5,$6,$7,$8}' | \
sort -k1,1 -k2,2 -k4,4 -k3,3 | gzip > ${STEP_DIR}/${PCR_COMBO}_CROP_sgRNAs.txt.gz
