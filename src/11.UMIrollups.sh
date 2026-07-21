#!/bin/bash

#SBATCH --job-name=SciPlex_UMI_Rollups
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

INPUT_DIR=$1
SAMPLE=$2
OUTPUT_DIR=$3

echo "========== Step 11 UMI Rollups. =========="
echo "Timestamp: $(date)"
echo "[PROCESS]  UMI Rollups..."
echo "[EXTERNAL] Executing SciPlex/src/11.UMIrollups.sh"


#How many UMI's per gene per combination

#on split(arr[1],namearr,"_") we are splitting the first column of the file by the underscore  i.e. we are keeping the name of the sample we are processing
#arr[5] is the combination of the RT and LIG barcode
#$2 only refers to the gene name
# then we print the gene name and the combination of the RT and LIG barcode
# then we sort the file by the first and second column
# then we count the number of UMIs for each gene and combination
# then we print the output to a file
FILE=$SAMPLE.txt
awk '$3 == "exonic" || $3 == "intronic" {
    split($1, arr, "|");
    split(arr[1],namearr,"_");#Sample name
    split(arr[5],subarr,"_");#Combination of RT and LIG barcode
    printf "%s|%s\t%s\n",
        namearr[1],arr[5], $2;
}' $INPUT_DIR/$FILE \
    | sort -k1,1 -k2,2 -S 2G \
    | datamash -g 1,2 count 2 \
    > "$OUTPUT_DIR/$FILE"

echo "[EXTERNAL] Finished UMI Rollups for: $FILE"

