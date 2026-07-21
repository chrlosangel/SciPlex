## Environment setup
```bash
mamba env create -f environment.yml

conda activate SciPlexFlow
```
## Execute
```bash
project_dir=/path/
fastq_available=1
organism=mouse
umis_cutoff=300
```

```bash
sbatch main.sh -p $project_dir -o $organism -f $fastq_available -u $umis_cutoff
```
