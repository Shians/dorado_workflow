# Dorado Basecalling Workflow

A Nextflow DSL2 pipeline for GPU-accelerated basecalling of Oxford Nanopore POD5 files using [Dorado](https://github.com/nanoporetech/dorado). Designed as an upstream workflow that generates basecalled BAM and FASTQ files for use in downstream analyses.

## Overview

This workflow:
1. Downloads the specified Dorado basecalling model
2. Builds a minimap2 index of the reference genome
3. Basecalls each POD5 file in parallel (GPU-accelerated)
4. Merges per-POD5 BAM files by sample
5. Converts merged BAMs to compressed FASTQ

## Requirements

### Software

- [Nextflow](https://www.nextflow.io/) ≥ 22.10.0
- [Singularity](https://sylabs.io/singularity/) (container runtime; Docker not supported by default profiles)

All bioinformatics tools (Dorado, minimap2, samtools, pigz) are provided via the container `oras://ghcr.io/shians/dorado-container:1.1.1-singularity`.

### Hardware

| Process | CPUs | Memory | Time limit |
|---|---|---|---|
| Basecalling (GPU) | 16 | 64 GB | 24h |
| Genome indexing | 8 | 32 GB | 12h |
| BAM merging | 8 | 32 GB | 12h |
| BAM → FASTQ | 4 | 16 GB | 4h |

An NVIDIA GPU (A30 or compatible) is required for basecalling. High-performance storage is recommended for POD5 files (1–5 GB per file).

## Inputs

### 1. POD5 Sample Sheet

A tab-separated file mapping sample identifiers to directories containing POD5 files.

**Format** (`pod5_sheet.tsv`):

```tsv
sample_id	path
sample_rep1	/data/nanopore/pod5/sample_replicate1
sample_rep2	/data/nanopore/pod5/sample_replicate2
sample_rep3	/data/nanopore/pod5/sample_replicate3_flowcell1
sample_rep3	/data/nanopore/pod5/sample_replicate3_flowcell2
```

- `sample_id`: Identifier for each sample (used to name output files). Multiple rows with the same `sample_id` are merged into a single output file, which is useful when one sample was sequenced across multiple flow cells or run folders.
- `path`: Absolute path to a directory containing `.pod5` files (searched recursively)

### 2. Reference Genome

A FASTA file used for alignment during basecalling (via minimap2). Gzipped FASTA (`.fa.gz`, `.fasta.gz`) is supported.

### 3. Basecalling Model

A Dorado model string. The workflow supports base models and modification models:

| Type | Example |
|---|---|
| Base model | `dna_r10.4.1_e8.2_400bps_sup@v5.2.0` |
| With modifications | `dna_r10.4.1_e8.2_400bps_sup@v5.2.0_5mCG_5hmCG@v2` |

**Supported modification codes:** `5mCG_5hmCG`, `5mC`, `6mA`, `5mC_5hmC`, `4mC_5mC`

Run `nextflow run shians/dorado_workflow --help` to list all valid model strings (requires Nextflow ≥ 25.10.0).

## Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--pod5_sheet` | Yes | — | Path to POD5 sample sheet TSV |
| `--reference_genome` | Yes | — | Path to reference genome FASTA |
| `--basecall_model` | Yes | — | Dorado basecalling model string |
| `--dna` | Yes* | `false` | DNA sequencing mode (uses `lr:hq` minimap2 preset) |
| `--cdna` | Yes* | `false` | cDNA sequencing mode (uses `splice:hq` minimap2 preset) |
| `--output_dir` | No | `"output"` | Root directory for output files |
| `--publish_merged_bams` | No | `true` | Save merged BAM files to output |
| `--publish_fastq` | No | `true` | Save converted FASTQ files to output |

*Exactly one of `--dna` or `--cdna` must be specified.

## Profiles

| Profile | Executor | Use Case |
|---|---|---|
| `singularity` | Local | Local machine with GPU and Singularity |
| `gpu_slurm` | SLURM | Generic SLURM cluster with GPU |
| `gpu_wehi` | SLURM | WEHI cluster (A30 GPU) |

## Configuring Resources

Resource limits are defined by process labels. To override them, create a `custom.config` file and pass it with `-c custom.config`.

| Label | Used by | Default CPUs | Default Memory | Default Time |
|---|---|---|---|---|
| `large` | Basecalling | 16 | 64 GB | 24h |
| `medium` | Genome indexing, BAM merging | 8 | 32 GB | 12h |
| `small` | Model download, BAM → FASTQ | 4 | 16 GB | 4h |

**Example `custom.config`:**

```groovy
process {
    withLabel: large {
        cpus   = 24
        memory = '128.GB'
        time   = '48h'
    }
    withLabel: medium {
        cpus   = 16
        memory = '64.GB'
        time   = '24h'
    }
}
```

Pass the custom config alongside a profile:

```bash
nextflow run shians/dorado_workflow \
  -profile gpu_wehi \
  -c custom.config \
  --pod5_sheet pod5_sheet.tsv \
  --reference_genome /path/to/genome.fa \
  --basecall_model "dna_r10.4.1_e8.2_400bps_sup@v5.2.0" \
  --dna
```

## Usage

### Basic Run

```bash
nextflow run main.nf \
  -profile gpu_wehi \
  --pod5_sheet pod5_sheet.tsv \
  --reference_genome /path/to/genome.fa \
  --basecall_model "dna_r10.4.1_e8.2_400bps_sup@v5.2.0" \
  --dna
```

### cDNA Mode

```bash
nextflow run main.nf \
  -profile gpu_wehi \
  --pod5_sheet pod5_sheet.tsv \
  --reference_genome /path/to/genome.fa \
  --basecall_model "dna_r10.4.1_e8.2_400bps_sup@v5.2.0" \
  --cdna
```

### With Modified Base Detection

```bash
nextflow run main.nf \
  -profile gpu_wehi \
  --pod5_sheet pod5_sheet.tsv \
  --reference_genome /path/to/genome.fa \
  --basecall_model "dna_r10.4.1_e8.2_400bps_sup@v5.2.0_5mCG_5hmCG@v2" \
  --dna
```

### Resume a Failed Run

```bash
nextflow run main.nf \
  -profile gpu_wehi \
  --pod5_sheet pod5_sheet.tsv \
  --reference_genome /path/to/genome.fa \
  --basecall_model "dna_r10.4.1_e8.2_400bps_sup@v5.2.0" \
  --dna \
  -resume
```

### Custom Output Directory

```bash
nextflow run main.nf \
  -profile gpu_wehi \
  --pod5_sheet pod5_sheet.tsv \
  --reference_genome /path/to/genome.fa \
  --basecall_model "dna_r10.4.1_e8.2_400bps_sup@v5.2.0" \
  --dna \
  --output_dir /scratch/project/basecalled
```

### BAM Output Only (Skip FASTQ)

```bash
nextflow run main.nf \
  -profile gpu_wehi \
  --pod5_sheet pod5_sheet.tsv \
  --reference_genome /path/to/genome.fa \
  --basecall_model "dna_r10.4.1_e8.2_400bps_sup@v5.2.0" \
  --dna \
  --publish_fastq false
```

## Output Structure

```
output/                        # Controlled by --output_dir
├── basecalled/                # Merged BAM files (one per sample)
│   ├── sample1.bam
│   └── sample2.bam
├── fastq/                     # Compressed FASTQ files (one per sample)
│   ├── sample1.fastq.gz
│   └── sample2.fastq.gz
└── logs/
    └── runtime_reports/
        ├── main_timeline.html # Interactive execution timeline
        ├── main_report.html   # Execution summary report
        └── main_trace.txt     # Detailed task trace log
```

BAM files include alignment tags from minimap2, making them suitable for downstream tools that use alignment information (e.g., splice site analysis, modification calling).

## References

- [Dorado](https://github.com/nanoporetech/dorado)
- [Nextflow Documentation](https://www.nextflow.io/docs/latest/)
