#!/bin/bash

#SBATCH --job-name=SciPlex_sgRNAMerge
#SBATCH --partition=cpu
#SBATCH --time=04:00:00
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

READS_STATS_DIR=$1
UMI_STATS_DIR=$2
SGRNA_BARCODES_FILE=$3
OUTPUT_DIR=$4
RUN_NAME=$5
SGRNA_MAP=$6


echo "========== Step 15 sgRNA Merge Counts. =========="
echo "Timestamp: $(date)"
echo "[PROCESS] Merging sgRNA read and UMI counts with gene names"
echo "[EXTERNAL] Executing SciPlex/src/15.sgrnamergecounts.sh"

OUT_DIR_READS="$READS_STATS_DIR/"
OUT_DIR_UMI="$UMI_STATS_DIR/"



MERGED="$(dirname "$READS_STATS_DIR")/../merged/"
mkdir -p "$MERGED"

echo "[INFO] Merging read and UMI count files"
for reads_file in "$OUT_DIR_READS"/*.txt; do
    prefix=$(basename "$reads_file" | cut -d'_' -f1)
    umi_file=$(find "$OUT_DIR_UMI" -type f -name "${prefix}_*")
    if [[ -f "$umi_file" ]]; then
        echo "[INFO] Processing $prefix"
        out_file="$MERGED/${prefix}_merged.txt"
        awk '{print $1"_"$2"_"$4, $0}' "$reads_file" | sort > reads.tmp
        awk '{print $1"_"$2"_"$4, $0}' "$umi_file"   | sort > umi.tmp
        join -1 1 -2 1 reads.tmp umi.tmp > "$out_file"
        awk '{print $2, $3, $4, $8, $5}' "$out_file" > tmp && mv tmp "$out_file"
        rm reads.tmp umi.tmp
    fi
done

MERGED_STATS="$MERGED/NA_stats_per_sample.txt"
> "$MERGED_STATS"
for i in "$MERGED"/*; do
    echo "File: $i"             >> "$MERGED_STATS"
    echo -n "NA GENES: "        >> "$MERGED_STATS"
    awk '{ if ($NF == "NA") count++ } END { print count+0 }' "$i" >> "$MERGED_STATS"
    echo -n "Total lines: "     >> "$MERGED_STATS"
    wc -l < "$i"                >> "$MERGED_STATS"
    echo "----"                 >> "$MERGED_STATS"
done

SGRNA_MATRIX="$OUTPUT_DIR/${RUN_NAME}_sgRNA_matrix.txt"
> "$SGRNA_MATRIX"
for i in "$MERGED"/*merged*; do
    if [[ -f "$i" ]]; then
        echo "[INFO] Adding $i to sgRNA matrix"
        cat "$i" >> "$SGRNA_MATRIX"
    fi
done

echo "[INFO] sgRNA matrix saved in: $SGRNA_MATRIX"
echo "[INFO] Step 15 sgRNA Merge complete"
