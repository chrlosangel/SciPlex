#!/bin/bash

#SBATCH --job-name=SciPlex_UMI_perSample
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

STEP_8_DIR=$1
STEP_6_DIR=$2
SAMPLE=$3
STEP_DIR=$4

echo "========== Step 10 UMI Per Sample. =========="
echo "Timestamp: $(date)"
echo "[PROCESS]  Getting UMI per Sample..."
echo "[EXTERNAL] Executing SciPlex/src/10.UMIpersample.sh"

PCR_WELL=$SAMPLE

awk '{
     split ($4, arr, "|"); # Split the 4th column using "|" as a delimiter
     key= arr[5] "|" arr[6]; #We define key as RT_Lig +  UMI
     if (!seen[arr[key]]) {
          seen[key] = 1; #Mark this UMI as counted for this RT_Lig combination
          count[arr[5]]++;
     }
} END {
     for (sample in count)
          print sample "\t" count[sample];
}' $STEP_8_DIR/$PCR_WELL.bed | sort -k1,1 \
> $STEP_DIR/$PCR_WELL.UMI.count #RT_Lig \t UMI count

echo "[UMI] Finished UMI counts for: $PCR_WELL"

#Takes headers cut and takes the 5th column which is the combination. Counts the # of times each combination appears, sorts them and sums them
samtools view $STEP_6_DIR/$PCR_WELL.bam | cut -d '|' -f 5 |  \
     datamash -g 1 count 1 | sort -k1,1 -S 2G | datamash -g 1 sum 2 \
     > $STEP_DIR/$PCR_WELL.reads.count #combination read amount, all reads 
 #The first column is the RT_lig and the second represents how many reads are assigned to each combination


