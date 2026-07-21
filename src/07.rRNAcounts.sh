#!/bin/bash

#SBATCH --job-name=SciPlex_count_rRNA
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

STEP_6_DIR=$1
SAMPLE=$2
RRNA_BED=$3
STEP_DIR=$4


echo "========== Step 7. Counting rRNA =========="
echo "Timestamp: $(date)"
echo "[PROCESS]  SAM Sort..."
echo "[EXTERNAL] Executing SciPlex/src/07.rRNAcounts.sh"


PCR_WELL=$SAMPLE

bedtools intersect -a $STEP_6_DIR/$SAMPLE.bam -b $RRNA_BED -c -nonamecheck -bed \
    | awk '{
        split($4, arr, "|");
        if (!seen[arr[1]]) {
            if ($NF > 0)
                rrna_count[arr[5]]++;
            total_count[arr[5]]++;
            seen[arr[1]] = 1;
        }
    } END {
        for (sample in total_count)
            printf "%s\t%d\t%d\n",
                sample, rrna_count[sample], total_count[sample];
    }' > $STEP_DIR/$PCR_WELL.txt
#read your sample as combination 
#Combination,amount of reads that overlap with rRNA regions, total amount of reads associated with that combination 

    echo "Processed $FILE"
done

