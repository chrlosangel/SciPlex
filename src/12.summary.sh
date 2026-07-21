#!/bin/bash

#SBATCH --job-name=SciPlex_Summary
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

STEP7_DIR=$1
STEP7_DIR_RANDOM=$2
STEP10_DIR=$3
STEP10_DIR_RANDOM=$4
OUTPUT_DIR=$5
OUTPUT_DIR_RANDOM=$6
RUN_NAME=$7

echo "========== Step 12 Summary. =========="
echo "Timestamp: $(date)"
echo "[PROCESS] Summarizing UMI, read, and rRNA counts"
echo "[EXTERNAL] Executing SciPlex/src/12.summary.sh"

# ----------- UMI counts -----------
# The difference between "per_sample" and "each_sample" is that the former 
# sums all UMIs for each sample, while the latter keeps track of UMIs for each individual file 
echo "[INFO] Summarizing UMI counts"

## ----------- Per sample summary -----------

cat "$STEP10_DIR"/*.UMI.count | sort -k1,1 | \
    datamash -g 1 sum 2 > "$OUTPUT_DIR/${RUN_NAME}_UMI_counts_per_sample.txt"

## ----------- Each sample summary -----------

for file in "$STEP10_DIR"/*.UMI.count; do
    awk -v name="$(basename "$file" .UMI.count)" '{print name "_" $0}' "$file"
done | sort -k1,1 | datamash -g 1 sum 2 \
    > "$OUTPUT_DIR/${RUN_NAME}_UMI_counts_each_sample.txt"

## ----------- Per sample summary -----------

echo "[INFO] Summarizing UMI counts (random)"
cat "$STEP10_DIR_RANDOM"/*.UMI.count | sort -k1,1 | \
    datamash -g 1 sum 2 > "$OUTPUT_DIR_RANDOM/${RUN_NAME}_UMI_counts_per_sample.txt"

## ----------- Each sample summary -----------

for file in "$STEP10_DIR_RANDOM"/*.UMI.count; do
    awk -v name="$(basename "$file" .UMI.count)" '{print name "_" $0}' "$file"
done | sort -k1,1 | datamash -g 1 sum 2 \
    > "$OUTPUT_DIR_RANDOM/${RUN_NAME}_UMI_counts_each_sample.txt"

# ----------- Read counts -----------
echo "[INFO] Summarizing read counts"
## ----------- Per sample summary -----------

cat "$STEP10_DIR"/*.reads.count | sort -k1,1 | \
    datamash -g 1 sum 2 > "$OUTPUT_DIR/${RUN_NAME}_reads_per_sample.txt"

## ----------- Each sample summary -----------

for file in "$STEP10_DIR"/*.reads.count; do
    awk -v name="$(basename "$file" .reads.count)" '{print name "_" $0}' "$file"
done | sort -k1,1 | datamash -g 1 sum 2 \
    > "$OUTPUT_DIR/${RUN_NAME}_reads_each_sample.txt"

## ----------- Per sample summary -----------

echo "[INFO] Summarizing read counts (random)"
cat "$STEP10_DIR_RANDOM"/*.reads.count | sort -k1,1 | \
    datamash -g 1 sum 2 > "$OUTPUT_DIR_RANDOM/${RUN_NAME}_reads_per_sample.txt"

## ----------- Each sample summary -----------

for file in "$STEP10_DIR_RANDOM"/*.reads.count; do
    awk -v name="$(basename "$file" .reads.count)" '{print name "_" $0}' "$file"
done | sort -k1,1 | datamash -g 1 sum 2 \
    > "$OUTPUT_DIR_RANDOM/${RUN_NAME}_reads_each_sample.txt"

# ----------- rRNA counts -----------
echo "[INFO] Summarizing rRNA counts"

## ----------- Per sample summary -----------

cat "$STEP7_DIR"/*.txt | sort -k1,1 | datamash -g 1 sum 2 sum 3 \
    > "$OUTPUT_DIR/${RUN_NAME}_rRNA_counts.txt"

## ----------- Each sample summary -----------

for file in "$STEP7_DIR"/*.txt; do
    awk -v name="$(basename "$file" .txt)" '{print name "_" $0}' "$file"
done | sort -k1,1 | datamash -g 1 sum 2 sum 3 \
    > "$OUTPUT_DIR/${RUN_NAME}_rRNA_counts_each_sample.txt"

## ----------- Per sample summary -----------
echo "[INFO] Summarizing rRNA counts (random)"
cat "$STEP7_DIR_RANDOM"/*.txt | sort -k1,1 | datamash -g 1 sum 2 sum 3 \
    > "$OUTPUT_DIR_RANDOM/${RUN_NAME}_rRNA_counts.txt"

## ----------- Each sample summary -----------

for file in "$STEP7_DIR_RANDOM"/*.txt; do
    awk -v name="$(basename "$file" .txt)" '{print name "_" $0}' "$file"
done | sort -k1,1 | datamash -g 1 sum 2 sum 3 \
    > "$OUTPUT_DIR_RANDOM/${RUN_NAME}_rRNA_counts_each_sample.txt"

# ----------- Sort for joining 
for f in \
    "$OUTPUT_DIR/${RUN_NAME}_UMI_counts_per_sample.txt" \
    "$OUTPUT_DIR/${RUN_NAME}_UMI_counts_each_sample.txt" \
    "$OUTPUT_DIR/${RUN_NAME}_reads_per_sample.txt" \
    "$OUTPUT_DIR/${RUN_NAME}_reads_each_sample.txt" \
    "$OUTPUT_DIR/${RUN_NAME}_rRNA_counts.txt" \
    "$OUTPUT_DIR/${RUN_NAME}_rRNA_counts_each_sample.txt" \
    "$OUTPUT_DIR_RANDOM/${RUN_NAME}_UMI_counts_per_sample.txt" \
    "$OUTPUT_DIR_RANDOM/${RUN_NAME}_UMI_counts_each_sample.txt" \
    "$OUTPUT_DIR_RANDOM/${RUN_NAME}_reads_per_sample.txt" \
    "$OUTPUT_DIR_RANDOM/${RUN_NAME}_reads_each_sample.txt" \
    "$OUTPUT_DIR_RANDOM/${RUN_NAME}_rRNA_counts.txt" \
    "$OUTPUT_DIR_RANDOM/${RUN_NAME}_rRNA_counts_each_sample.txt"; do
    sort -k1,1 "$f" > "${f%.txt}.sorted.txt"
done

# ----------- General Stats 
echo "[INFO] Computing General Stats"

_stats() {
    local rRNA=$1 umi=$2 reads=$3 out=$4
    join "$rRNA" "$umi" | join - "$reads" | \
    awk 'BEGIN {
        printf "SAMPLE\tNUMBER_READS\tPERCENTAGE_rRNA\tNUMBER_UMIs\tDUP_RATE\n";
    } {
        printf "%s\t%d\t%.1f%%\t%d\t%.1f%%\n",
        $1, $3, 100 * $2 / $3, $4, 100 * (1 - $4 / $5);
    }' > "$out"
}

## ----------- Per sample stats -----------

_stats \
    "$OUTPUT_DIR/${RUN_NAME}_rRNA_counts.sorted.txt" \
    "$OUTPUT_DIR/${RUN_NAME}_UMI_counts_per_sample.sorted.txt" \
    "$OUTPUT_DIR/${RUN_NAME}_reads_per_sample.sorted.txt" \
    "$OUTPUT_DIR/${RUN_NAME}_General_Stats.txt"

## ----------- Each sample stats -----------
_stats \
    "$OUTPUT_DIR/${RUN_NAME}_rRNA_counts_each_sample.sorted.txt" \
    "$OUTPUT_DIR/${RUN_NAME}_UMI_counts_each_sample.sorted.txt" \
    "$OUTPUT_DIR/${RUN_NAME}_reads_each_sample.sorted.txt" \
    "$OUTPUT_DIR/${RUN_NAME}_General_Stats_each_sample.txt"

# ----------- Per sample stats (random) -----------
_stats \
    "$OUTPUT_DIR_RANDOM/${RUN_NAME}_rRNA_counts.sorted.txt" \
    "$OUTPUT_DIR_RANDOM/${RUN_NAME}_UMI_counts_per_sample.sorted.txt" \
    "$OUTPUT_DIR_RANDOM/${RUN_NAME}_reads_per_sample.sorted.txt" \
    "$OUTPUT_DIR_RANDOM/${RUN_NAME}_General_Stats.txt"

## ----------- Each sample stats (random) -----------
_stats \
    "$OUTPUT_DIR_RANDOM/${RUN_NAME}_rRNA_counts_each_sample.sorted.txt" \
    "$OUTPUT_DIR_RANDOM/${RUN_NAME}_UMI_counts_each_sample.sorted.txt" \
    "$OUTPUT_DIR_RANDOM/${RUN_NAME}_reads_each_sample.sorted.txt" \
    "$OUTPUT_DIR_RANDOM/${RUN_NAME}_General_Stats_each_sample.txt"

## ----------- Cleanup -----------
rm "$OUTPUT_DIR/"*.sorted.txt "$OUTPUT_DIR_RANDOM/"*.sorted.txt

echo "[INFO] General Stats saved in: $OUTPUT_DIR/${RUN_NAME}_General_Stats.txt"
cat "$OUTPUT_DIR/${RUN_NAME}_General_Stats.txt"
echo "[INFO] Step 12 Summary complete"
