#!/bin/bash
#SBATCH --job-name=SciPlex_Workflow
#SBATCH --time=20:00:00
#SBATCH --partition=cpu
#SBATCH --cpus-per-task=1
#SBATCH --mem=10G
#SBATCH --output=./PBS/SciPlex_Workflow_%j.out

if command -v conda &> /dev/null; then
    echo "[INFO] Using conda environment SciPlexFlow"
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate SciPlexFlow
else
    echo "[ERROR] Conda is not installed or not in PATH. Please install Conda."
    exit 1
fi

# ----------- User defined variables -----------

usage() {
    echo "Usage: $0 -p [project_dir] -o [organism] -f [fastq_available]"
    echo "  -p [project_dir]       : Path to the project directory [must contain data/ and metaData/ subdirectories]"
    echo "  -o [organism]          : Organism name"
    echo "  -f [fastq_available]   : Fastq files available (0: no, 1: yes)"
    echo "  -u [umis_cutoff]       : UMI cutoff for cell filtering"

    exit 1
}

while [[ "$#" -gt 0 ]]; do
     case $1 in
          -p|--project_dir) project_dir="$2"; shift ;;
          -o|--organism) organism="$2"; shift ;;
          -f|--fastq_available) fastq_available="$2"; shift ;;
          -u|--umis_cutoff) umis_cutoff="$2"; shift ;;
     *) echo "[SciPlex] [ERROR] Unknown parameter: $1"; exit 1 ;;
     esac
done

generate_index_key(){
     local rt_barcodes_file="$1"
     local lig_barcodes_file="$2"
     local project_dir="$3"

     paste $rt_barcodes_file $lig_barcodes_file | awk '{
     sample_num = NR;
     printf "SciPlex%d\tSciPlex%d\n", sample_num, sample_num;
     }' > "$project_dir/combinatorial_indexing.key"
}

setup_sciplex_workflow() {
    if [[ -z "$project_dir" || -z "$organism" || -z "$fastq_available" ]]; then
        echo "[ERROR] Missing required parameters."
        usage
    fi

    if [[ ! -d "$project_dir/data" || ! -d "$project_dir/metaData" ]]; then
        echo "[ERROR] Project directory must contain 'data/' and 'metaData/' subdirectories."
        exit 1
    fi

    execute_path="./"

    echo "[INFO] Executing SciPlex workflow from: $execute_path"

    echo "[INFO] Setting up SciPlex workflow with the following parameters:"
    echo "       Project Directory: $project_dir"
    echo "       Organism: $organism"
    echo "       Fastq Available: $fastq_available"

    echo "[INFO] Finding metaData files in $project_dir/metaData/"
    rt_barcodes_file=$(find "$project_dir/metaData/" -type f -name "RT.txt")
     if [[ -z "$rt_barcodes_file" ]]; then
          echo "[ERROR] No RT barcodes file found in $project_dir/metaData/"
          echo "[ERROR] Make sure it exists and is named correctly i.e. starts with 'RT'."
          #exit 1
     else
          echo "[INFO] Found RT barcodes file: $rt_barcodes_file"
     fi

     lig_barcodes_file=$(find "$project_dir/metaData/" -type f -name "Ligation.txt")
     if [[ -z "$lig_barcodes_file" ]]; then
          echo "[ERROR] No Lig barcodes file found in $project_dir/metaData/"
          echo "[ERROR] Make sure it exists and is named correctly i.e. starts with 'Lig'."
          #exit 1
     else
          echo "[INFO] Found Lig barcodes file: $lig_barcodes_file"
     fi

     sgrna_barcodes_file=$(find "$project_dir/metaData/" -type f -name "CROP_sgRNA.txt")
     awk '{map[$2] = $1} END {for (k in map) print k, map[k]}' "${sgrna_barcodes_file}" > "$(dirname "$sgrna_barcodes_file")/sgRNA_map.txt"
     sgRNA_map_file="$(dirname "$sgrna_barcodes_file")/sgRNA_map.txt"
     if [[ -z "$sgrna_barcodes_file" ]]; then
          echo "[ERROR] No CROP sgRNA barcodes file found in $project_dir/metaData/"
          echo "[ERROR] Make sure it exists and is named correctly i.e. starts with 'CROP_sgRNA'."
          #exit 1
     else
          echo "[INFO] Found CROP sgRNA barcodes file: $sgrna_barcodes_file"
     fi

     random_barcodes_file=$(find "$project_dir/metaData/" -type f -name "RandomHex.txt")
     if [[ -z "$random_barcodes_file" ]]; then
          echo "[ERROR] No Random barcodes file found in $project_dir/metaData/"
          echo "[ERROR] Make sure it exists and is named correctly i.e. starts with 'Random'."
          #exit 1
     else
          echo "[INFO] Found Random barcodes file: $random_barcodes_file"
     fi


     run_name=$(basename $project_dir)
     echo "[INFO] Run name set to: $run_name"
     echo "[INFO] Generating combinatorial index key file..."
     generate_index_key "$rt_barcodes_file" "$lig_barcodes_file" "$project_dir"
     echo "[INFO] Combinatorial index key file generated at: $project_dir/combinatorial_indexing.key"
     indexing_key="$project_dir/combinatorial_indexing.key"

     log_file="$project_dir/SciPlex_workflow.log"
     echo "[INFO] Starting SciPlex workflow execution. Logs will be saved to: $log_file"
     echo "----------------------------------------" >> "$log_file"
     echo "[INFO] Workflow execution started at: $(date)" >> "$log_file"
     echo "[INFO] Workflow parameters:" >> "$log_file"
     echo "       Project Directory: $project_dir" >> "$log_file"
     echo "       Organism: $organism" >> "$log_file"
     echo "       Fastq Available: $fastq_available" >> "$log_file"
     echo "       RT Barcodes File: $rt_barcodes_file" >> "$log_file"
     echo "       Lig Barcodes File: $lig_barcodes_file" >> "$log_file"
     echo "       CROP sgRNA Barcodes File: $sgrna_barcodes_file" >> "$log_file"
     echo "       sgRNA Map File: $sgRNA_map_file" >> "$log_file"

     echo "       Random Barcodes File: $random_barcodes_file" >> "$log_file"
     echo "       Indexing Key: $indexing_key" >> "$log_file"
     echo "----------------------------------------" >> "$log_file"
}

generate_star_index(){
     local star_index_dir="$1"
     local organism="$2"

     echo "[INFO] STAR index will be saved to: $star_index_dir" >&2
     mkdir -p "$star_index_dir"
     echo "[INFO] STAR index directory created at: $star_index_dir" >&2
     local job_id=$(sbatch --parsable src/starindex.sh "$star_index_dir" "$organism")
     echo "[INFO] STAR index job submitted with job ID: $job_id" >&2
     echo "$job_id"
}

generate_gene_model(){
     execute_path="./"
     mkdir -p "$execute_path/reference/$organism"
     echo "[INFO] Generating gene model for organism: $organism"
     echo "[INFO] Gene model will be saved to: $execute_path/reference/$organism/"

     model_dir=$(realpath "$execute_path/reference/$organism/")
     mkdir -p "$model_dir"

     echo "[INFO] Model directory will include the following files and STAR index:"
     echo "       - $model_dir/${organism}_exons.bed"
     echo "       - $model_dir/${organism}_genes.bed"
     echo "       - $model_dir/${organism}_gene.annotations"
     echo "       - $model_dir/${organism}_rRNA_gene_regions.bed"
     echo "       - $model_dir/STAR_index/"

     mkdir -p "$model_dir/STAR_index/"
     if [[ -f "$model_dir/STAR_index/SA" ]]; then
          echo "[INFO] STAR index already exists. Skipping STAR index generation."
          index_job_id=""
     else
          echo "[INFO] STAR index not found. Generating STAR index..."
          index_job_id=$(generate_star_index "$model_dir/STAR_index" "$organism")
     fi

     if [[ -f "$model_dir/${organism}_gene.annotations" && -f "$model_dir/${organism}_exons.bed" && -f "$model_dir/${organism}_genes.bed" && -f "$model_dir/${organism}_rRNA_gene_regions.bed" ]]; then
          echo "[INFO] Gene model files already exist. Skipping gene model generation."
          model_job_id=""
     else
          echo "[INFO] Gene model files not found. Generating gene model files..."
          model_id=$(sbatch --parsable src/genemodel.sh "$model_dir" "$organism")

     fi
}

generate_log_step(){
     local step_name="$1"
     touch ${project_dir}/PBS/${step_name}.log
     echo "========== Step $step_name ==========" >> ${project_dir}/PBS/${step_name}.log
     echo "Timestamp: $(date)" >> ${project_dir}/PBS/${step_name}.log
     echo "[PROCESS] Starting step: $step_name" >> ${project_dir}/PBS/${step_name}.log
     echo "[EXTERNAL] Executing SciPlex/$step_name.sh" >> ${project_dir}/PBS/${step_name}.log
}

get_expected_observed(){
     local samples_file="$1"
     local observed_dir="$2"
     local pattern="$3"
     local expected=$(wc -l < "$samples_file")
     local processed=$(ls "$observed_dir"/*"$pattern" 2>/dev/null | wc -l)
     echo "$expected $processed"
}

setup_directories() {
    fastq_dir_step1="$project_dir/1-output-fastq-combined-runs"

    step2_dir="$project_dir/2-combined-fastq-shortdT"
    step2_dir_random="$project_dir/2-combined-fastq-random"

    step3_dir="$project_dir/3-sgRNAs/"
    step3_dir_random="$project_dir/3-sgRNAs_Random/"
    step3_stats_dir="$project_dir/3-sgRNAs_stats/"
    step3_reads_stats_dir="$step3_stats_dir/read_counts_by_sample/"
    step3_umi_stats_dir="$step3_stats_dir/umi_counts_by_sample/"

    step4_dir="$project_dir/4-trim_polyA/"
    step4_dir_random="$project_dir/4-trim_polyA_random/"

    step5_dir="$project_dir/5-alignment/"
    step5_dir_random="$project_dir/5-alignment_random/"

    step6_dir="$project_dir/6-filtered_sorted_bam/"
    step6_dir_random="$project_dir/6-filtered_sorted_bam_random/"

    step7_dir="$project_dir/7-rRNA_counts/"
    step7_dir_random="$project_dir/7-rRNA_counts_random/"

    step8_dir="$project_dir/8-BED_files/"
    step8_dir_random="$project_dir/8-BED_files_random/"

    step9_dir="$project_dir/9-gene_counts/"
    step9_dir_random="$project_dir/9-gene_counts_random/"
    step9_dir_all="$project_dir/9-gene_counts_ALL/"

    step10_dir="$project_dir/10-UMI_per_sample/"
    step10_dir_random="$project_dir/10-UMI_per_sample_random/"

    step11_dir="$project_dir/11-UMI_rollups/"
    step11_dir_all="$project_dir/11-UMI_rollups_ALL/"

    step12_dir="$project_dir/12-SciPlex_output/"
    step12_dir_random="$project_dir/12-SciPlex_output_random/"
    step12_dir_all="$project_dir/12-SciPlex_output_ALL/"

    mkdir -p "$project_dir/PBS" \
             "$step2_dir" "$step2_dir_random" \
             "$step3_dir" "$step3_dir_random" \
             "$step3_reads_stats_dir" "$step3_umi_stats_dir" \
             "$step4_dir" "$step4_dir_random" \
             "$step5_dir" "$step5_dir_random" \
             "$step6_dir" "$step6_dir_random" \
             "$step7_dir" "$step7_dir_random" \
             "$step8_dir" "$step8_dir_random" \
             "$step9_dir" "$step9_dir_random"  \
             "$step9_dir_all" \
             "$step10_dir" "$step10_dir_random" \
             "$step11_dir" "$step11_dir_all" \
             "$step12_dir" "$step12_dir_random" "$step12_dir_all"
}

# -----------------------------------------
setup_sciplex_workflow
exec > >(tee -a "$log_file") 2>&1
setup_directories
generate_gene_model

model_dir=$(realpath "$execute_path/reference/$organism/")
gene_annotation="$model_dir/${organism}_gene.annotations"
genes_bed="$model_dir/${organism}_genes.bed"
exons_bed="$model_dir/${organism}_exons.bed"
rrna_bed="$model_dir/${organism}_rRNA_gene_regions.bed"

echo "[INFO] Gene model generation completed. Gene model files are located at: $model_dir"
echo "[INFO] Gene annotation file: $gene_annotation"
echo "[INFO] Genes BED file: $genes_bed"
echo "[INFO] Exons BED file: $exons_bed"
echo "[INFO] rRNA gene regions BED file: $rrna_bed"

echo "----------------- SciPlex Workflow Initialization Complete -----------------"
echo "Timestamp: $(date)"

# working dir is the same as project dir

echo "----------------- Step 1: Combine fastq files from multiple runs -----------------"
combine_fastq_job_id=""
if [[ "$fastq_available" -eq 1 ]]; then
     echo "[INFO] Fastq files are available. Starting fastq combination step..."
     generate_log_step "01.combinefastqs"
     if [[ -d "$fastq_dir_step1" ]]; then
          echo "[INFO] Output directory for combined fastq files already exists. Skipping fastq combination step."
          combine_fastq_job_id=""
     else
          combine_fastq_job_id=$(sbatch --parsable \
                              --output="$project_dir/PBS/01.combinefastqs.log" \
                              --error="$project_dir/PBS/01.combinefastqs.log" \
                              src/01.combinefastqs.sh \
                              "$project_dir/data" \
                              "$project_dir" \
                              "$fastq_available" \
                              )
     fi

     echo "[INFO] Fastq combination job submitted with job ID: $combine_fastq_job_id"
else
     echo "[INFO] Fastq files are not available. Skipping fastq combination step."
     echo "[INFO] Please ensure that fastq files are placed in $project_dir/data and set the -f parameter to 1 to enable fastq combination."
     exit 1
fi
# The end result of this step is $project_dir/1-output-fastq-combined-runs/sample_name/sample_name_R1.fastq.gz and $project_dir/1-output-fastq-combined-runs/sample_name/sample_name_R2.fastq.gz

# ===================================================================================================#
# Step 2. Put read 1 information (RT well, UMI) into read 2
# ===================================================================================================#

echo "----------------- Step 2: Put read 1 information into read 2 -----------------"

# only files no directories
samples=$(ls -p "$project_dir/data/" 2>/dev/null | sed 's/_R1.fastq.gz//g' | grep -v "/" |grep -v R2 | grep -v Adept | grep -v DefaultProject)
samples_file="$project_dir/SciPlex_samples.txt"
echo "$samples" > "$samples_file"

#previous/current step
expected_step2=$(get_expected_observed "$samples_file" "$step2_dir" "fastq.gz" | cut -d' ' -f1)
processed_step2=$(get_expected_observed "$fastq_dir_step1" "$step2_dir" "fastq.gz" | cut -d' ' -f2)

step2_job_ids=()
if [[ "$expected_step2" -eq "$processed_step2" && "$expected_step2" -gt 0 ]]; then
     echo "[INFO] All Step 2 output files already exist. Skipping."
     # We need to add a fake job ID otherwise the random step will not run because it depends on the completion of this step
     step2_job_ids+=("0")
else
     awk_script="./src/02.putr1intor2.awk"
     while IFS= read -r sample; do
          generate_log_step "02.putr1intor2_${sample}"
          log_step2="$project_dir/PBS/02.putr1intor2_${sample}.log"
          dep=""
          [[ -n "$combine_fastq_job_id" ]] && dep="--dependency=afterok:$combine_fastq_job_id"
          job2_id=$(sbatch --parsable $dep \
               --output="$log_step2" \
               --error="$log_step2" \
               src/02.putr1intor2.sh \
               "$fastq_dir_step1" \
               "$sample" \
               "$rt_barcodes_file" \
               "$lig_barcodes_file" \
               "$indexing_key" \
               "$step2_dir" \
               "$awk_script")
          step2_job_ids+=("$job2_id")
          echo "[INFO] Step 2 job submitted for sample $sample with job ID: $job2_id"
     done < "$samples_file"
     echo "[INFO] All Step 2 jobs submitted: ${step2_job_ids[*]}"
fi

dependency_step2=$(IFS=:; echo "${step2_job_ids[*]}")

echo "----------------- Step 2: Random -----------------"

expected_step2_random=$(get_expected_observed "$samples_file" "$step2_dir_random" "fastq.gz"| cut -d' ' -f1)
processed_step2_random=$(get_expected_observed "$samples_file" "$step2_dir_random" "fastq.gz"| cut -d' ' -f2)

step2_job_ids_random=()
if [[ "$expected_step2_random" -eq "$processed_step2_random" && "$expected_step2_random" -gt 0 ]]; then
     echo "[INFO] All Step 2 output files already exist. Skipping."

else
     awk_script="./src/02.putr1intor2.awk"
     while IFS= read -r sample; do
          generate_log_step "02.putr1intor2_random_${sample}"
          log_step2r="$project_dir/PBS/02.putr1intor2_random_${sample}.log"
          dep="" # if we dont have anything then empty
          # if we do have a job ID from the previous step then we want to add a dependency on that job ID
          [[ -n "$combine_fastq_job_id" ]] && dep="--dependency=afterok:$combine_fastq_job_id"
          job2r_id=$(sbatch --parsable $dep \
               --output="$log_step2r" \
               --error="$log_step2r" \
               src/02.putr1intor2.sh \
               "$fastq_dir_step1" \
               "$sample" \
               "$random_barcodes_file" \
               "$lig_barcodes_file" \
               "$indexing_key" \
               "$step2_dir_random" \
               "$awk_script")
          step2_job_ids_random+=("$job2r_id")
          echo "[INFO] Step 2 random job submitted for sample $sample with job ID: $job2r_id"
     done < "$samples_file"
     echo "[INFO] All Step 2 random jobs submitted: ${step2_job_ids_random[*]}"
fi
dependency_step2_random=$(IFS=:; echo "${step2_job_ids_random[*]}")

echo "----------------- Step 3: Parse sgRNA barcodes -----------------"
#previousstep2_dir="$project_dir/2-combined-fastq-shortdT"

expected_step3=$(get_expected_observed "$samples_file" "$step3_dir" "fastq.gz" | cut -d' ' -f1)
processed_step3=$(get_expected_observed "$samples_file" "$step3_dir" "fastq.gz" | cut -d' ' -f2)

step3_job_ids=()
if [[ "$expected_step3" -eq "$processed_step3" && "$expected_step3" -gt 0 ]]; then
     echo "[INFO] All Step 3 output files already exist. Skipping."
else
     awk_file="./src/03.sgRNAs.awk"
     while IFS= read -r sample; do
          generate_log_step "03.parse_sgrna_${sample}"
          log_step3="$project_dir/PBS/03.parse_sgrna_${sample}.log"
          dep=""
          [[ -n "$dependency_step2" ]] && dep="--dependency=afterok:$dependency_step2"
          job3_id=$(sbatch $dep \
               --output="$log_step3" \
               --error="$log_step3" \
               src/03.sgRNAbarcodes.sh \
               "$step2_dir" \
               "$sample" \
               "$sgrna_barcodes_file" \
               "$step3_dir" "$(realpath $awk_file)" | awk '{print $4}')
          step3_job_ids+=("$job3_id")
          echo "[INFO] Step 3 job submitted for sample $sample with job ID: $job3_id"
     done < "$samples_file"
fi
dependency_step3=$(IFS=:; echo "${step3_job_ids[*]}")


echo "----------------- Step 3: Parse sgRNA barcodes Random -----------------"
#previousstep2_dir="$project_dir/2-combined-fastq-shortdT"

expected_step3r=$(get_expected_observed "$samples_file" "$step3_dir_random" "fastq.gz" | cut -d' ' -f1)
processed_step3r=$(get_expected_observed "$samples_file" "$step3_dir_random" "fastq.gz" | cut -d' ' -f2)
step3r_job_ids=()
if [[ "$expected_step3r" -eq "$processed_step3r" && "$expected_step3r" -gt 0 ]]; then
     echo "[INFO] All Step 3 output files already exist. Skipping."
else
     awk_file="./src/03.sgRNAs.awk"
     while IFS= read -r sample; do
          generate_log_step "03.parse_sgrna_random_${sample}"
          log_step3r="$project_dir/PBS/03.parse_sgrna_random_${sample}.log"
          dep=""
          [[ -n "$dependency_step2_random" ]] && dep="--dependency=afterok:$dependency_step2_random"
          job3r_id=$(sbatch $dep \
               --output="$log_step3r" \
               --error="$log_step3r" \
               src/03.sgRNAbarcodes.sh \
               "$step2_dir_random" \
               "$sample" \
               "$sgrna_barcodes_file" \
               "$step3_dir_random" \
               "$(realpath $awk_file)" | awk '{print $4}')
          step3r_job_ids+=("$job3r_id")
          echo "[INFO] Step 3 job submitted for sample $sample with job ID: $job3r_id"
     done < "$samples_file"
fi
dependency_step3_random=$(IFS=:; echo "${step3r_job_ids[*]}")

echo "----------------- Step 3: Stats for Crop sgRNA -----------------"

expected_step3_stats=$(get_expected_observed "$samples_file" "$step3_stats_dir" "txt" | cut -d' ' -f1)
processed_step3_stats=$(get_expected_observed "$samples_file" "$step3_stats_dir" "txt" | cut -d' ' -f2)
step3_stats_job_ids=()



if [[ "$expected_step3_stats" -eq "$processed_step3_stats" && "$expected_step3_stats" -gt 0 ]]; then
     echo "[INFO] All Step 3 stats output files already exist. Skipping."
else
     while IFS= read -r sample; do
          generate_log_step "03.sgRNA_stats_${sample}"
          log_step3_stats="$project_dir/PBS/03.sgRNA_stats_${sample}.log"
          dep=""
          [[ -n "$dependency_step3" ]] && dep="--dependency=afterok:$dependency_step3"
          job3_stats_id=$(sbatch --parsable $dep \
               --output="$log_step3_stats" \
               --error="$log_step3_stats" \
               src/03.1.sgRNAReadCountspersample.sh \
               "$step3_dir" \
               "$sample" \
               "$(dirname "$sgrna_barcodes_file")/sgRNA_map.txt" \
               "$step3_reads_stats_dir")
          step3_stats_job_ids+=("$job3_stats_id")
          echo "[INFO] Step 3 stats job submitted for sample $sample with job ID: $job3_stats_id"
          job3_umi_stats_id=$(sbatch --parsable $dep \
               --output="$log_step3_stats" \
               --error="$log_step3_stats" \
               src/03.1.sgRNAUMICountspersample.sh \
               "$step3_dir" \
               "$sample" \
               "$(dirname "$sgrna_barcodes_file")/sgRNA_map.txt" \
               "$step3_umi_stats_dir")
          step3_umi_stats_job_ids+=("$job3_umi_stats_id")
          echo "[INFO] Step 3 UMI stats job submitted for sample $sample with job ID: $job3_umi_stats_id"
     done < "$samples_file"
fi

echo "----------------- Step 4: Trim PolyA tails -----------------"

expected_step4=$(get_expected_observed "$samples_file" "$step4_dir" "txt.gz" | cut -d' ' -f1)
processed_step4=$(get_expected_observed "$samples_file" "$step4_dir" "txt.gz" | cut -d' ' -f2)
step4_job_ids=()
if [[ "$expected_step4" -eq "$processed_step4" && "$expected_step4" -gt 0 ]]; then
     echo "[INFO] All Step 4 output files already exist. Skipping."
else
     while IFS= read -r sample; do
          generate_log_step "04.trim_polyA_${sample}"
          log_step4="$project_dir/PBS/04.trim_polyA_${sample}.log"
          dep=""
          [[ -n "$dependency_step3" ]] && dep="--dependency=afterok:$dependency_step3"
          job4_id=$(sbatch --parsable $dep \
               --output="$log_step4" \
               --error="$log_step4" \
               src/04.trimpolyA.sh \
               "$step2_dir" \
               "$step4_dir" \
               "$sample")
          step4_job_ids+=("$job4_id")
          echo "[INFO] Step 4 job submitted for sample $sample with job ID: $job4_id"
     done < "$samples_file"
fi
dependency_step4=$(IFS=:; echo "${step4_job_ids[*]}")

echo "----------------- Step 4: Trim PolyA tails Random -----------------"

expected_step4r=$(get_expected_observed "$samples_file" "$step4_dir_random" "txt.gz" | cut -d' ' -f1)
processed_step4r=$(get_expected_observed "$samples_file" "$step4_dir_random" "txt.gz" | cut -d' ' -f2)
step4r_job_ids=()
if [[ "$expected_step4r" -eq "$processed_step4r" && "$expected_step4r" -gt 0 ]]; then
     echo "[INFO] All Step 4 output files already exist. Skipping."
else
     while IFS= read -r sample; do
          generate_log_step "04.trim_polyA_random_${sample}"
          log_step4r="$project_dir/PBS/04.trim_polyA_random_${sample}.log"
          dep=""
          [[ -n "$dependency_step3_random" ]] && dep="--dependency=afterok:$dependency_step3_random"
          job4r_id=$(sbatch --parsable $dep \
               --output="$log_step4r" \
               --error="$log_step4r" \
               src/04.trimpolyA.sh \
               "$step2_dir_random" \
               "$step4_dir_random" \
               "$sample")
          step4r_job_ids+=("$job4r_id")
          echo "[INFO] Step 4 job submitted for sample $sample with job ID: $job4r_id"
     done < "$samples_file"
fi
dependency_step4_random=$(IFS=:; echo "${step4r_job_ids[*]}")

# ===================================================================================================#
echo "----------------- Step 5: Align reads to gene model -----------------"

expected_step5=$(get_expected_observed "$samples_file" "$step5_dir" "bam" | cut -d' ' -f1)
processed_step5=$(get_expected_observed "$samples_file" "$step5_dir" "bam" | cut -d' ' -f2)
step5_job_ids=()
if [[ "$expected_step5" -eq "$processed_step5" && "$expected_step5" -gt 0 ]]; then
     echo "[INFO] All Step 5 output files already exist. Skipping."
else
     while IFS= read -r sample; do
          generate_log_step "05.align_${sample}"
          log_step5="$project_dir/PBS/05.align_${sample}.log"
          dep=""
          [[ -n "$dependency_step4" ]] && dep="--dependency=afterok:$dependency_step4"
          job5_id=$(sbatch --parsable $dep \
               --output="$log_step5" \
               --error="$log_step5" \
               src/05.star.sh \
               "$step4_dir" \
               "$sample" \
               "$model_dir/STAR_index" \
               "$step5_dir")
          step5_job_ids+=("$job5_id")
          echo "[INFO] Step 5 job submitted for sample $sample with job ID: $job5_id"
     done < "$samples_file"
fi
dependency_step5=$(IFS=:; echo "${step5_job_ids[*]}")

echo "----------------- Step 5: Align reads to gene model Random -----------------"

expected_step5r=$(get_expected_observed "$samples_file" "$step5_dir_random" "bam" | cut -d' ' -f1)
processed_step5r=$(get_expected_observed "$samples_file" "$step5_dir_random" "bam" | cut -d' ' -f2)
step5r_job_ids=()
if [[ "$expected_step5r" -eq "$processed_step5r" && "$expected_step5r" -gt 0 ]]; then
     echo "[INFO] All Step 5 output files already exist. Skipping."
else
     while IFS= read -r sample; do
          generate_log_step "05.align_random_${sample}"
          log_step5r="$project_dir/PBS/05.align_random_${sample}.log"
          dep=""
          [[ -n "$dependency_step4_random" ]] && dep="--dependency=afterok:$dependency_step4_random"
          job5r_id=$(sbatch --parsable $dep \
               --output="$log_step5r" \
               --error="$log_step5r" \
               src/05.star.sh \
               "$step4_dir_random" \
               "$sample" \
               "$model_dir/STAR_index" \
               "$step5_dir_random")
          step5r_job_ids+=("$job5r_id")
          echo "[INFO] Step 5 random job submitted for sample $sample with job ID: $job5r_id"
     done < "$samples_file"
fi
dependency_step5_random=$(IFS=:; echo "${step5r_job_ids[*]}")

echo "----------------- Step 6: Filter ambiguous alignments and sort bam -----------------"

expected_step6=$(get_expected_observed "$samples_file" "$step6_dir" "bam" | cut -d' ' -f1)
processed_step6=$(get_expected_observed "$samples_file" "$step6_dir" "bam" | cut -d' ' -f2)
step6_job_ids=()
if [[ "$expected_step6" -eq "$processed_step6" && "$expected_step6" -gt 0 ]]; then
     echo "[INFO] All Step 6 output files already exist. Skipping."
else
     while IFS= read -r sample; do
          generate_log_step "06.filter_sort_${sample}"
          log_step6="$project_dir/PBS/06.filter_sort_${sample}.log"
          dep=""
          [[ -n "$dependency_step5" ]] && dep="--dependency=afterok:$dependency_step5"
          job6_id=$(sbatch --parsable $dep \
               --output="$log_step6" \
               --error="$log_step6" \
               src/06.sort.sh \
               "$step5_dir" \
               "$sample" \
               "$step6_dir")
          step6_job_ids+=("$job6_id")
          echo "[INFO] Step 6 job submitted for sample $sample with job ID: $job6_id"
     done < "$samples_file"
fi
dependency_step6=$(IFS=:; echo "${step6_job_ids[*]}")

echo "----------------- Step 6: Filter ambiguous alignments and sort bam Random -----------------"

expected_step6r=$(get_expected_observed "$samples_file" "$step6_dir_random" "bam" | cut -d' ' -f1)
processed_step6r=$(get_expected_observed "$samples_file" "$step6_dir_random" "bam" | cut -d' ' -f2)

step6r_job_ids=()
if [[ "$expected_step6r" -eq "$processed_step6r" && "$expected_step6r" -gt 0 ]]; then
     echo "[INFO] All Step 6 output files already exist. Skipping."
else
     while IFS= read -r sample; do
          generate_log_step "06.filter_sort_random_${sample}"
          log_step6r="$project_dir/PBS/06.filter_sort_random_${sample}.log"
          dep=""
          [[ -n "$dependency_step5_random" ]] && dep="--dependency=afterok:$dependency_step5_random"
          job6r_id=$(sbatch --parsable $dep \
               --output="$log_step6r" \
               --error="$log_step6r" \
               src/06.sort.sh \
               "$step5_dir_random" \
               "$sample" \
               "$step6_dir_random")
          step6r_job_ids+=("$job6r_id")
          echo "[INFO] Step 6 random job submitted for sample $sample with job ID: $job6r_id"
     done < "$samples_file"
fi
dependency_step6_random=$(IFS=:; echo "${step6r_job_ids[*]}")


echo "----------------- Step 7: Count rRNA -----------------"

expected_step7=$(get_expected_observed "$samples_file" "$step7_dir" "txt" | cut -d' ' -f1)
processed_step7=$(get_expected_observed "$samples_file" "$step7_dir" "txt" | cut -d' ' -f2)
step7_job_ids=()
if [[ "$expected_step7" -eq "$processed_step7" && "$expected_step7" -gt 0 ]]; then
     echo "[INFO] All Step 7 output files already exist. Skipping."
else
     while IFS= read -r sample; do
          generate_log_step "07.count_rRNA_${sample}"
          log_step7="$project_dir/PBS/07.count_rRNA_${sample}.log"
          dep=""
          [[ -n "$dependency_step6" ]] && dep="--dependency=afterok:$dependency_step6"
          job7_id=$(sbatch --parsable $dep \
               --output="$log_step7" \
               --error="$log_step7" \
               src/07.rRNAcounts.sh \
               "$step6_dir" \
               "$sample" \
               "$rrna_bed" \
               "$step7_dir")
          step7_job_ids+=("$job7_id")
          echo "[INFO] Step 7 job submitted for sample $sample with job ID: $job7_id"
     done < "$samples_file"
fi

echo "----------------- Step 7: Count rRNA Random -----------------"

expected_step7r=$(get_expected_observed "$samples_file" "$step7_dir_random" "txt" | cut -d' ' -f1)
processed_step7r=$(get_expected_observed "$samples_file" "$step7_dir_random" "txt" | cut -d' ' -f2)
step7r_job_ids=()
if [[ "$expected_step7r" -eq "$processed_step7r" && "$expected_step7r" -gt 0 ]]; then
     echo "[INFO] All Step 7 output files already exist. Skipping."
else
     while IFS= read -r sample; do
          generate_log_step "07.count_rRNA_random_${sample}"
          log_step7r="$project_dir/PBS/07.count_rRNA_random_${sample}.log"
          dep=""
          [[ -n "$dependency_step6_random" ]] && dep="--dependency=afterok:$dependency_step6_random"
          job7r_id=$(sbatch --parsable $dep \
               --output="$log_step7r" \
               --error="$log_step7r" \
               src/07.rRNAcounts.sh \
               "$step6_dir_random" \
               "$sample" \
               "$rrna_bed" \
               "$step7_dir_random")
          step7r_job_ids+=("$job7r_id")
          echo "[INFO] Step 7 random job submitted for sample $sample with job ID: $job7r_id"
     done < "$samples_file"
fi

echo "----------------- Step 8: Make BED files -----------------"

expected_step8=$(get_expected_observed "$samples_file" "$step8_dir" "bed" | cut -d' ' -f1)
processed_step8=$(get_expected_observed "$samples_file" "$step8_dir" "bed" | cut -d' ' -f2)
step8_job_ids=()
if [[ "$expected_step8" -eq "$processed_step8" && "$expected_step8" -gt 0 ]]; then
     echo "[INFO] All Step 8 output files already exist. Skipping."
else
     awk_step8="./src/08.rmdup.awk"
     while IFS= read -r sample; do
          generate_log_step "08.make_bed_${sample}"
          log_step8="$project_dir/PBS/08.make_bed_${sample}.log"
          dep=""
          [[ -n "$dependency_step6" ]] && dep="--dependency=afterok:$dependency_step6"
          job8_id=$(sbatch --parsable $dep \
               --output="$log_step8" \
               --error="$log_step8" \
               src/08.bed.sh \
               "$step6_dir" \
               "$sample" \
               "$step8_dir" \
               "$(realpath $awk_step8)")
          step8_job_ids+=("$job8_id")
          echo "[INFO] Step 8 job submitted for sample $sample with job ID: $job8_id"
     done < "$samples_file"
fi
dependency_step8=$(IFS=:; echo "${step8_job_ids[*]}")


echo "----------------- Step 8: Make BED files Random -----------------"
expected_step8r=$(get_expected_observed "$samples_file" "$step8_dir_random" "bed" | cut -d' ' -f1)
processed_step8r=$(get_expected_observed "$samples_file" "$step8_dir_random" "bed" | cut -d' ' -f2)
step8r_job_ids=()
if [[ "$expected_step8r" -eq "$processed_step8r" && "$expected_step8r" -gt 0 ]]; then
     echo "[INFO] All Step 8 output files already exist. Skipping."
else
     awk_step8="./src/08.rmdup.awk"
     while IFS= read -r sample; do
          generate_log_step "08.make_bed_random_${sample}"
          log_step8r="$project_dir/PBS/08.make_bed_random_${sample}.log"
          dep=""
          [[ -n "$dependency_step6_random" ]] && dep="--dependency=afterok:$dependency_step6_random"
          job8r_id=$(sbatch --parsable $dep \
               --output="$log_step8r" \
               --error="$log_step8r" \
               src/08.bed.sh \
               "$step6_dir_random" \
               "$sample" \
               "$step8_dir_random" \
               "$(realpath $awk_step8)")
          step8r_job_ids+=("$job8r_id")
          echo "[INFO] Step 8 random job submitted for sample $sample with job ID: $job8r_id"
     done < "$samples_file"
fi
dependency_step8_random=$(IFS=:; echo "${step8r_job_ids[*]}")

echo "----------------- Step 9: Count reads in genes -----------------"

expected_step9=$(get_expected_observed "$samples_file" "$step9_dir" "txt" | cut -d' ' -f1)
processed_step9=$(get_expected_observed "$samples_file" "$step9_dir" "txt" | cut -d' ' -f2)
step9_job_ids=()
if [[ "$expected_step9" -eq "$processed_step9" && "$expected_step9" -gt 0 ]]; then
     echo "[INFO] All Step 9 output files already exist. Skipping."
else
     PYTHON_SCRIPT="./src/09.countGenes.py"
     while IFS= read -r sample; do
          generate_log_step "09.count_genes_${sample}"
          log_step9="$project_dir/PBS/09.count_genes_${sample}.log"
          dep=""
          [[ -n "$dependency_step8" ]] && dep="--dependency=afterok:$dependency_step8"
          job9_id=$(sbatch --parsable $dep \
               --output="$log_step9" \
               --error="$log_step9" \
               src/09.countGenes.sh \
               "$step8_dir" \
               "$sample" \
               "$genes_bed" \
               "$exons_bed" \
               "$PYTHON_SCRIPT" \
               "$step9_dir")
          step9_job_ids+=("$job9_id")
          echo "[INFO] Step 9 job submitted for sample $sample with job ID: $job9_id"
     done < "$samples_file"
fi
dependency_step9=$(IFS=:; echo "${step9_job_ids[*]}")

echo "----------------- Step 9: Count reads in genes Random -----------------"
expected_step9r=$(get_expected_observed "$samples_file" "$step9_dir_random" "txt" | cut -d' ' -f1)
processed_step9r=$(get_expected_observed "$samples_file" "$step9_dir_random" "txt" | cut -d' ' -f2)
step9r_job_ids=()
if [[ "$expected_step9r" -eq "$processed_step9r" && "$expected_step9r" -gt 0 ]]; then
     echo "[INFO] All Step 9 output files already exist. Skipping."
else
     PYTHON_SCRIPT="./src/09.countGenes.py"
     while IFS= read -r sample; do
          generate_log_step "09.count_genes_random_${sample}"
          log_step9r="$project_dir/PBS/09.count_genes_random_${sample}.log"
          dep=""
          [[ -n "$dependency_step8_random" ]] && dep="--dependency=afterok:$dependency_step8_random"
          job9r_id=$(sbatch --parsable $dep \
               --output="$log_step9r" \
               --error="$log_step9r" \
               src/09.countGenes.sh \
               "$step8_dir_random" \
               "$sample" \
               "$genes_bed" \
               "$exons_bed" \
               "$PYTHON_SCRIPT" \
               "$step9_dir_random")
          step9r_job_ids+=("$job9r_id")
          echo "[INFO] Step 9 random job submitted for sample $sample with job ID: $job9r_id"
     done < "$samples_file"
fi
dependency_step9_random=$(IFS=:; echo "${step9r_job_ids[*]}")

echo "----------------- Step 9.1: Count reads ALL (shortdT + random) -----------------"
expected_step9_all=$(get_expected_observed "$samples_file" "$step9_dir_all" "txt" | cut -d' ' -f1)
processed_step9_all=$(get_expected_observed "$samples_file" "$step9_dir_all" "txt" | cut -d' ' -f2)
step9_all_job_ids=()
if [[ "$expected_step9_all" -eq "$processed_step9_all" && "$expected_step9_all" -gt 0 ]]; then
     echo "[INFO] All Step 9.1 output files already exist. Skipping."
else
     for file in ${step9_dir}/*.txt; do
          > "$step9_dir_all/shortdT_$(basename "$file")" # create empty file with new name
          if [[ -f "$file" ]]; then
               cat $file >> "$step9_dir_all/shortdT_$(basename "$file")"
          fi
     done

     for file in ${step9_dir_random}/*.txt; do
          > "$step9_dir_all/randomN_$(basename "$file")" # create empty file with new name
          if [[ -f "$file" ]]; then
               cat $file >> "$step9_dir_all/randomN_$(basename "$file")"
          fi
     done
fi

echo "----------------- Step10 : UMI per sample -----------------"

expected_step10=$(get_expected_observed "$samples_file" "$step10_dir" "txt" | cut -d' ' -f1)
processed_step10=$(get_expected_observed "$samples_file" "$step10_dir" "txt" | cut -d' ' -f2)
step10_job_ids=()
if [[ "$expected_step10" -eq "$processed_step10" && "$expected_step10" -gt 0 ]]; then
     echo "[INFO] All Step 10 output files already exist. Skipping."
else
     while IFS= read -r sample; do
          generate_log_step "10.UMI_per_sample_${sample}"
          log_step10="$project_dir/PBS/10.UMI_per_sample_${sample}.log"
          dep=""
          [[ -n "$dependency_step8" ]] && dep="--dependency=afterok:$dependency_step8"
          job10_id=$(sbatch --parsable $dep \
               --output="$log_step10" \
               --error="$log_step10" \
               src/10.UMIpersample.sh \
               "$step8_dir" \
               "$step6_dir" \
               "$sample" \
               "$step10_dir")
          step10_job_ids+=("$job10_id")
          echo "[INFO] Step 10 job submitted for sample $sample with job ID: $job10_id"
     done < "$samples_file"
fi
dependency_step10=$(IFS=:; echo "${step10_job_ids[*]}")

echo "----------------- Step10 : UMI per sample Random -----------------"
expected_step10r=$(get_expected_observed "$samples_file" "$step10_dir_random" "txt" | cut -d' ' -f1)
processed_step10r=$(get_expected_observed "$samples_file" "$step10_dir_random" "txt" | cut -d' ' -f2)
step10r_job_ids=()
if [[ "$expected_step10r" -eq "$processed_step10r" && "$expected_step10r" -gt 0 ]]; then
     echo "[INFO] All Step 10 output files already exist. Skipping."
else
     while IFS= read -r sample; do
          generate_log_step "10.UMI_per_sample_random_${sample}"
          log_step10r="$project_dir/PBS/10.UMI_per_sample_random_${sample}.log"
          dep=""
          [[ -n "$dependency_step8_random" ]] && dep="--dependency=afterok:$dependency_step8_random"
          job10r_id=$(sbatch --parsable $dep \
               --output="$log_step10r" \
               --error="$log_step10r" \
               src/10.UMIpersample.sh \
               "$step8_dir_random" \
               "$step6_dir_random" \
               "$sample" \
               "$step10_dir_random")
          step10r_job_ids+=("$job10r_id")
          echo "[INFO] Step 10 random job submitted for sample $sample with job ID: $job10r_id"
     done < "$samples_file"
fi
dependency_step10_random=$(IFS=:; echo "${step10r_job_ids[*]}")


echo "----------------- Step11: UMI rollups -----------------"
expected_step11=$(get_expected_observed "$samples_file" "$step11_dir" "txt" | cut -d' ' -f1)
processed_step11=$(get_expected_observed "$samples_file" "$step11_dir" "txt" | cut -d' ' -f2)
step11_job_ids=()
if [[ "$expected_step11" -eq "$processed_step11" && "$expected_step11" -gt 0 ]]; then
     echo "[INFO] All Step 11 output files already exist. Skipping."
else
     while IFS= read -r sample; do
          generate_log_step "11.UMI_rollups_${sample}"
          log_step11="$project_dir/PBS/11.UMI_rollups_${sample}.log"
          dep=""
          [[ -n "$dependency_step10" ]] && dep="--dependency=afterok:$dependency_step10"
          job11_id=$(sbatch --parsable $dep \
               --output="$log_step11" \
               --error="$log_step11" \
               src/11.UMIrollups.sh \
               "$step9_dir" \
               "$sample" \
               "$step11_dir")
          step11_job_ids+=("$job11_id")
          echo "[INFO] Step 11 job submitted with job ID: $job11_id"
     done < "$samples_file"
fi
dependency_step11=$(IFS=:; echo "${step11_job_ids[*]}")

echo "----------------- Step11: UMI rollups All -----------------"
expected_step11_all=$(get_expected_observed "$samples_file" "$step11_dir_all" "txt" | cut -d' ' -f1)
processed_step11_all=$(get_expected_observed "$samples_file" "$step11_dir_all" "txt" | cut -d' ' -f2)
step11_all_job_ids=()
patterns=("shortdT_" "randomN_")
if [[ "$expected_step11_all" -eq "$processed_step11_all" && "$expected_step11_all" -gt 0 ]]; then
     echo "[INFO] All Step 11 ALL output files already exist. Skipping."
else
     while IFS= read -r sample; do
          generate_log_step "11.UMI_rollups_all_${sample}"
          log_step11_all="$project_dir/PBS/11.UMI_rollups_all_${sample}.log"
          dep=""
          [[ -n "$dependency_step10" ]] && dep="--dependency=afterok:$dependency_step10"
          for pattern in "${patterns[@]}"; do
               job11_all_id=$(sbatch --parsable $dep \
                    --output="$log_step11_all" \
                    --error="$log_step11_all" \
                    src/11.UMIrollups.sh \
                    "$step9_dir_all" \
                    "${pattern}${sample}" \
                    "$step11_dir_all")
               step11_all_job_ids+=("$job11_all_id")
          done
          echo "[INFO] Step 11 ALL job submitted with job ID: $job11_all_id"
     done < "$samples_file"
fi
dependency_step11_all=$(IFS=:; echo "${step11_all_job_ids[*]}")
#
echo "----------------- Step 12: Summarize UMI, Read, and rRNA Counts -----------------"

generate_log_step "12.summary"
log_step12="$project_dir/PBS/12.summary.log"
dep=""
dep_parts=()
[[ -n "$dependency_step7" ]]  && dep_parts+=("$dependency_step7")
[[ -n "$dependency_step10" ]] && dep_parts+=("$dependency_step10")
[[ -n "$dependency_step11" ]] && dep_parts+=("$dependency_step11")
[[ ${#dep_parts[@]} -gt 0 ]] && dep="--dependency=afterok:$(IFS=:; echo "${dep_parts[*]}")"
step12_job_id=$(sbatch --parsable $dep \
     --output="$log_step12" \
     --error="$log_step12" \
     src/12.summary.sh \
     "$step7_dir" \
     "$step7_dir_random" \
     "$step10_dir" \
     "$step10_dir_random" \
     "$step12_dir" \
     "$step12_dir_random" \
     "$run_name")
echo "[INFO] Step 12 job submitted with job ID: $step12_job_id"
dependency_step12="$step12_job_id"

echo "----------------- Step 13: Annotate UMI Rollups -----------------"

generate_log_step "13.annotatematrix"
log_step13="$project_dir/PBS/13.annotatematrix.log"
dep=""
[[ -n "$dependency_step12" ]] && dep="--dependency=afterok:$dependency_step12"
step13_job_id=$(sbatch --parsable $dep \
     --output="$log_step13" \
     --error="$log_step13" \
     src/13.annotatematrix.sh \
     "$step11_dir" \
     "$step12_dir" \
     "$genes_bed" \
     "$run_name" \
     "$umis_cutoff")
echo "[INFO] Step 13 job submitted with job ID: $step13_job_id"
dependency_step13="$step13_job_id"



echo "----------------- Step 13.1: Annotate UMI Rollups ALL -----------------"

generate_log_step "13.annotatematrix_all"
log_step13_all="$project_dir/PBS/13.annotatematrix_all.log"
dep=""
[[ -n "$dependency_step12" ]] && dep="--dependency=afterok:$dependency_step12"
step13_job_id_all=$(sbatch --parsable $dep \
     --output="$log_step13_all" \
     --error="$log_step13_all" \
     src/13.annotatematrix.sh \
     "$step11_dir_all" \
     "$step12_dir_all" \
     "$genes_bed" \
     "$run_name" \
     "$umis_cutoff")
echo "[INFO] Step 13 job submitted with job ID: $step13_job_id_all"
dependency_step13_all="$step13_job_id_all"

echo "----------------- Step 14: Generate CellDataSet -----------------"
# nedd to add all part 
generate_log_step "14.celldataset"
log_step14="$project_dir/PBS/14.celldataset.log"
dep=""
[[ -n "$dependency_step13" ]] && dep="--dependency=afterok:$dependency_step13"
step14_job_id=$(sbatch --parsable $dep \
     --output="$log_step14" \
     --error="$log_step14" \
     src/14.celldataset.sh \
     "$step12_dir" \
     "$run_name")

step14_job_id_all=$(sbatch --parsable $dep \
     --output="$log_step14" \
     --error="$log_step14" \
     src/14.celldataset.sh \
     "$step12_dir_all" \
     "$run_name")
echo "[INFO] Step 14 job submitted with job ID: $step14_job_id"
dependency_step14="$step14_job_id:$step14_job_id_all"


echo "----------------- Step 15: sgRNA Merge -----------------"

generate_log_step "15.sgrnamergecounts"
log_step15="$project_dir/PBS/15.sgrnamergecounts.log"
dep=""
dep_parts=()
[[ -n "$dependency_step3" ]]  && dep_parts+=("$dependency_step3")
[[ -n "$dependency_step14" ]] && dep_parts+=("$dependency_step14")
[[ ${#dep_parts[@]} -gt 0 ]] && dep="--dependency=afterok:$(IFS=:; echo "${dep_parts[*]}")"
step15_job_id=$(sbatch --parsable $dep \
     --output="$log_step15" \
     --error="$log_step15" \
     src/15.sgrnamergecounts.sh \
     "$step3_reads_stats_dir/with_gene_names" \
     "$step3_umi_stats_dir/with_gene_names" \
     "$sgrna_barcodes_file" \
     "$step12_dir_all" \
     "$run_name" \
     ""$sgRNA_map_file"")
echo "[INFO] Step 15 job submitted with job ID: $step15_job_id"
dependency_step15="$step15_job_id"
