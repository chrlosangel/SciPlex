#!/bin/bash

#SBATCH --job-name=SciPlex_CellDataSet
#SBATCH --partition=cpu
#SBATCH --time=04:00:00
#SBATCH --mem=20G
#SBATCH --nodes=1

if command -v conda &> /dev/null; then
    echo "[INFO] Using conda environment SciPlexFlow"
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate SciPlexFlow
else
    echo "[ERROR] Conda is not installed or not in PATH. Please install Conda."
    exit 1
fi

OUTPUT_DIR=$1
RUN_NAME=$2

EXECUTE_PATH="./src"

echo "========== Step 14 Generate CellDataSet. =========="
echo "Timestamp: $(date)"
echo "[PROCESS] Generating CellDataSet from count matrix"

echo "[INFO] Running CellDataSet generation"
Rscript "$EXECUTE_PATH/generateCellDataSet.R" \
    "$OUTPUT_DIR/${RUN_NAME}_UMI.count.matrix" \
    "$OUTPUT_DIR/genes_unique.bed" \
    "$OUTPUT_DIR/${RUN_NAME}_cell_annotations.txt" \
    "$OUTPUT_DIR"

echo "[INFO] CellDataSet saved in: $OUTPUT_DIR"
echo "[INFO] Step 14 CellDataSet complete"
