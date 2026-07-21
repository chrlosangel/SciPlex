#!/bin/bash
#SBATCH --job-name=starindex
#SBATCH --time=20:00:00
#SBATCH --partition=cpu
#SBATCH --cpus-per-task=6
#SBATCH --mem=40G
#SBATCH --output=./PBS/star_index_%j.out

if command -v conda &> /dev/null; then
    echo "[INFO] Using conda environment SciPlexFlow"
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate SciPlexFlow
else
    echo "[ERROR] Conda is not installed or not in PATH. Please install Conda."
    exit 1
fi

DIR=$1 #"$execute_path/reference/$organism/STAR_index/"
ORGANISM=$2
MODEL_DIR=$(dirname "$DIR") ##"$execute_path/reference/$organism/

if [ ! -d "$MODEL_DIR" ]; then
  echo "Model directory $MODEL_DIR does not exist. Creating it."
  mkdir -p "$MODEL_DIR"
fi

mkdir -p $MODEL_DIR/genome/

if [ "$ORGANISM" == "mouse" ]; then
     GENOMEDIR=$MODEL_DIR/genome/
     if [[ ! -f "$GENOMEDIR/mm10.fasta" || ! -f "$GENOMEDIR/mm10.refGene.gtf" ]]; then
          echo "Downloading mouse genome and annotation files..."
          wget -P $GENOMEDIR https://hgdownload.soe.ucsc.edu/goldenPath/mm10/bigZips/mm10.fa.gz
          wget -P $GENOMEDIR https://hgdownload.soe.ucsc.edu/goldenPath/mm10/bigZips/genes/mm10.refGene.gtf.gz
          gunzip $GENOMEDIR/mm10.fa.gz
          mv $GENOMEDIR/mm10.fa $GENOMEDIR/mm10.fasta
          gunzip $GENOMEDIR/mm10.refGene.gtf.gz
     else
          echo "Mouse genome and annotation files already exist. Skipping download."
     fi
fi

if [ "$ORGANISM" == "mouse" ]; then
     STAR --runThreadN 6 \
          --runMode genomeGenerate \
          --genomeDir $DIR \
          --genomeFastaFiles $GENOMEDIR/mm10.fasta \
          --sjdbGTFfile $GENOMEDIR/mm10.refGene.gtf
elif [ "$ORGANISM" == "human" ]; then
     echo '[ERROR] Human genome indexing not implemented yet.'
else
     echo '[ERROR] Unsupported organism specified. Please use "mouse" or "human".'
     exit 1
fi
## STAR --runThreadN 1 --runMode genomeGenerate \
#--genomeDir $GENOMEDIR/STAR --genomeFastaFiles 
# $GENOMEDIR/GRCh38.primary_assembly.genome.chr19.fa 
# --sjdbGTFfile $GENOMEDIR/gencode.v29.primary_assembly.annotation.chr19.gtf

