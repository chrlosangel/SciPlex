#!/bin/bash
#SBATCH --job-name=SciPlex_TrimPolyA
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

STEP_2_DIR=$1
STEP_DIR=$2
SAMPLE=$3

echo "========== Step 4. Trimming PolyA =========="
echo "Timestamp: $(date)"
echo "[PROCESS]  Trimming PolyA..."
echo "[EXTERNAL] Executing SciPlex/src/04.trimpolyA.sh"

echo "[INFO] Processing sample: ${SAMPLE}"

trim_galore ${STEP_2_DIR}/${SAMPLE}.fastq.gz -a AAAAAAAA --three_prime_clip_R1 1 --gzip -o ${STEP_DIR}
echo "[INFO] Done processing sample: ${SAMPLE}"
done
     