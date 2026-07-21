#!/bin/bash

#SBATCH --job-name=SciPlex_AnnotateMatrix
#SBATCH --partition=cpu
#SBATCH --time=10:00:00
#SBATCH --mem=30G
#SBATCH --nodes=1

if command -v conda &> /dev/null; then
    echo "[INFO] Using conda environment SciPlexFlow"
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate SciPlexFlow
else
    echo "[ERROR] Conda is not installed or not in PATH. Please install Conda."
    exit 1
fi

STEP11_DIR=$1
OUTPUT_DIR=$2
GENES_BED=$3
RUN_NAME=$4
UMI_PER_CELL_CUTOFF=$5

echo "========== Step 13 Annotate Matrix. =========="
echo "Timestamp: $(date)"
echo "[PROCESS] Annotating UMI rollups and building count matrix"
echo "[EXTERNAL] Executing SciPlex/src/13.annotatematrix.sh"

SAMPLES_EXC="samples_to_exclude.txt"
if [[ ! -f "$SAMPLES_EXC" ]]; then
    echo "[INFO] $SAMPLES_EXC not found. Creating an empty file."
    touch "$SAMPLES_EXC"
fi


echo "[INFO] UMI_PER_CELL_CUTOFF = $UMI_PER_CELL_CUTOFF"

# Concatenate all UMI rollup files
ORIGINAL_ROLL="$OUTPUT_DIR/${RUN_NAME}_UMI_rollups.txt.gz" 
echo "[INFO] Concatenating rollups from: $STEP11_DIR"
cat "$STEP11_DIR"/*.txt | gzip > "$ORIGINAL_ROLL"

# Filter cells above UMI cutoff
echo "[INFO] Filtering cells with more than $UMI_PER_CELL_CUTOFF UMIs"
gunzip < "$ORIGINAL_ROLL" \
    | datamash -g 1 sum 3 \
    | tr '|' '\t' \
    | awk -v CUTOFF="$UMI_PER_CELL_CUTOFF" '
    ARGIND == 1 {
        exclude[$1] = 1
    } $3 > CUTOFF && !($1 in exclude) {
        print $2 "\t" $1"|"$2
    }' "$SAMPLES_EXC" - \
    | sort -k1,1 -S 4G \
    > "$OUTPUT_DIR/${RUN_NAME}_cell_annotations.txt"

echo "[INFO] Cell annotations saved in: $OUTPUT_DIR/${RUN_NAME}_cell_annotations.txt"

# Deduplicate gene names
cp "$GENES_BED" "$OUTPUT_DIR/genes_forProcessing.bed"
awk '!seen[$4]++' "$OUTPUT_DIR/genes_forProcessing.bed" > "$OUTPUT_DIR/genes_unique.bed"

# Build count matrix
echo "[INFO] Building UMI count matrix"
gunzip < "$ORIGINAL_ROLL" \
| tr '|' '\t' \
| awk '{
    gsub(/^[ \t]+|[ \t]+$/, "", $1);
    gsub(/^[ \t]+|[ \t]+$/, "", $2);
    gsub(/^[ \t]+|[ \t]+$/, "", $3);
    if (ARGIND == 1) {
        if (!($4 in gene_idx)) {
            gene_idx[$4] = ++gene_idx_counter;
        }
    } else if (ARGIND == 2) {
        cell_idx[$2] = FNR;
    } else {
        my_id = $1 "|" $2;
        if (my_id in cell_idx) {
            printf "%d\t%d\t%d\n", gene_idx[$3], cell_idx[my_id], $4;
        }
    }
}' "$OUTPUT_DIR/genes_unique.bed" \
   "$OUTPUT_DIR/${RUN_NAME}_cell_annotations.txt" \
   - > "$OUTPUT_DIR/${RUN_NAME}_UMI.count.matrix"

echo "[INFO] Count matrix saved in: $OUTPUT_DIR/${RUN_NAME}_UMI.count.matrix"
echo "[INFO] Step 13 Annotate Matrix complete"
