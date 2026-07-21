## Environment setup
mamba env create -f environment.yml

conda activate SciPlexFlow

## Execute

project_dir=/users/jcc2340/g2lab/NGSAnalysis/Zarmeen/25_05_26_SciPlex/
fastq_available=1
organism=mouse
umis_cutoff=300

```bash
sbatch main.sh -p $project_dir -o $organism -f $fastq_available -u $umis_cutoff
```