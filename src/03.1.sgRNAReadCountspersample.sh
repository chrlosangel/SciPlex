#!/bin/bash
#SBATCH --job-name=SciPlex_sgRNA_ReadCounts
#SBATCH --time=15:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=10G

if command -v conda &> /dev/null; then
    echo "[INFO] Using conda environment SciPlexFlow"
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate SciPlexFlow
else
    echo "[ERROR] Conda is not installed or not in PATH. Please install Conda."
    exit 1
fi

# Arguments
step3_dir=$1
sample=$2
sgRNA_map_file=$3
output_dir=$4
output_dir_wname=$4/with_gene_names/
mkdir -p "$output_dir_wname"

SGRNA_INPUT_FILE=$step3_dir/${sample}_CROP_sgRNAs.txt.gz
SGRNA_OUTPUT_FILE=$output_dir/${sample}_sgRNA_read_counts.txt
SGRNA_OUTPUT_FILE_WITH_MAP=$output_dir_wname/${sample}_sgRNA_read_counts_gene_mapped.txt 
# Check if input directory exists
if [[ ! -f "$SGRNA_INPUT_FILE" ]]; then
    echo "[ERROR] SGRNA_INPUT_FILE does not exist: $SGRNA_INPUT_FILE"
    exit 1
fi


echo "[INFO] Starting sgRNA processing on SLURM..."
echo "[INFO] Input directory: $SGRNA_INPUT_FILE"
echo "[INFO] Output file: $SGRNA_OUTPUT_FILE"


echo "[INFO] Processing ${SGRNA_INPUT_FILE} file..."

#Print the sample,RT_LIG,sgRNA,UMI_barcode
#then ptiny only Cell_ID and sgRNA
#Count the reads by Cell_ID and sgRNA
#Print the Cell_ID,sgRNA,Reads
# Run the pipeline on all files
zcat "${SGRNA_INPUT_FILE}" | \
    awk '{print $1"_"$2, $4, $3}' | \
    awk '{print $1, $2}' | \
    sort | uniq -c | awk '{print $2, $3, $1}' > "${SGRNA_OUTPUT_FILE}" 

echo "[INFO] Processing completed. Output saved to: $SGRNA_OUTPUT_FILE"

# Processing with sgRNA map
awk 'NR==FNR {map[$1]=$2; next} {id=map[$2]; print $0, (id ? id : "NA")}' "${sgRNA_map_file}" "${SGRNA_OUTPUT_FILE}" > "${SGRNA_OUTPUT_FILE_WITH_MAP}"
