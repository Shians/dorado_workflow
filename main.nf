// Import modules
include { doradoDownloadModel; doradoBaseCall } from './modules/basecalling/main.nf'
include { buildMinimapIndexGenome } from './modules/indexing/main.nf'
include { mergeBams; bamToFastq } from './modules/preprocessing/main.nf'
include { validateParams } from './modules/validation/main.nf'
include { createChannelFromPod5Sheet } from './modules/pod5_sheet/main.nf'

def helpMessage() {
    log.info """
    ===================================
    Dorado Workflow - Basecalling Pipeline
    ===================================

    Usage:
      nextflow run main.nf [options]

    Required Parameters:
      --pod5_sheet PATH                Path to POD5 sheet TSV file
      --reference_genome PATH          Path to reference genome FASTA file
      --basecall_model STRING          Dorado model name

    Optional Parameters:
      --output_dir PATH                Output directory (default: output)

    POD5 Sheet Format:
      The POD5 sheet must be a tab-separated (TSV) file with the following columns:
        - sample_id: Unique identifier for each sample
        - path: Directory containing POD5 files for this sample

      The workflow will:
        1. Find all *.pod5 files in each directory
        2. Basecall each POD5 file in parallel using Dorado
        3. Merge BAM files by sample_id
        4. Convert merged BAMs to FASTQ format

      Example (columns separated by tabs):
        sample_id	path
        sample1	/data/pod5/sample1/
        sample2	/data/pod5/sample2/

    Basecalling:
      Dorado basecalling with GPU acceleration. The workflow:
        - Downloads the specified basecalling model
        - Basecalls each POD5 file with alignment to reference genome
        - Generates BAM files with alignment information

      Common basecalling models:
        - R10.4.1 E8.2: dna_r10.4.1_e8.2_400bps_sup@v5.0.0
        - R10.4.1 E8.2 (5kHz): dna_r10.4.1_e8.2_400bps_sup@v5.0.0_5khz
        - R9.4.1: dna_r9.4.1_e8_sup@v3.6

    Publishing Options:
      Control which intermediate and final results are saved:
        --publish.merged_bams BOOL       Save merged BAM files (default: true)
        --publish.fastq BOOL             Save FASTQ files (default: true)

    Execution Profiles:
      -profile singularity                Use Singularity for dependency management
      -profile slurm_gpu                  SLURM cluster with GPU support

    Other Options:
      --help                              Display this help message

    Example:
      nextflow run main.nf \\
        --pod5_sheet pod5_sheet.tsv \\
        --reference_genome /path/to/genome.fa \\
        --basecall_model dna_r10.4.1_e8.2_400bps_sup@v5.0.0 \\
        --output_dir results \\
        -profile singularity
    """
}

workflow {
    // Show help message if requested
    if (params.help) {
        helpMessage()
        exit 0
    }

    // Validate parameters
    validateParams()

    // Download Dorado model
    model_path = doradoDownloadModel(params.basecall_model)

    // Get reference genome path
    ref_genome_path = Channel.fromPath(params.reference_genome)

    // Build minimap2 index for genome (optional, for alignment during basecalling)
    ref_genome_index = buildMinimapIndexGenome(ref_genome_path)

    // Parse POD5 sheet and create channel
    pod5_channel = createChannelFromPod5Sheet(params.pod5_sheet)

    // Combine POD5 files with model and reference genome for basecalling
    pod5_files = pod5_channel
        .combine(model_path)
        .combine(ref_genome_path)

    // Basecall POD5 files
    basecalled_bams = doradoBaseCall(pod5_files)

    // Merge BAM files by sample_id
    merged_bams = basecalled_bams
        .groupTuple()
        .map { sample, paths ->
            tuple(sample, paths.flatten())
        }
        | mergeBams

    // Convert merged BAMs to FASTQ
    bamToFastq(merged_bams)
}
