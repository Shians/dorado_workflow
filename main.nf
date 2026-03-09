nextflow.enable.dsl=2

include { validateParameters; paramsSummaryLog } from 'plugin/nf-schema'

// Import modules
include { doradoDownloadModel; doradoBaseCall } from './modules/basecalling/main.nf'
include { buildMinimapIndexGenome } from './modules/indexing/main.nf'
include { mergeBams; bamToFastq } from './modules/preprocessing/main.nf'
include { createChannelFromPod5Sheet } from './modules/pod5_sheet/main.nf'

workflow {
    // Validate parameters against schema and print summary
    validateParameters()
    log.info paramsSummaryLog(workflow)

    minimap2_preset = params.rna ? 'splice:hq' : 'lr:hq'

    // Download Dorado model
    model_path = doradoDownloadModel(params.basecall_model)

    // Get reference genome path
    ref_genome_path = channel.fromPath(params.reference_genome)

    // Build minimap2 index for genome (optional, for alignment during basecalling)
    ref_genome_index = buildMinimapIndexGenome(ref_genome_path, channel.value(minimap2_preset))

    // Parse POD5 sheet and create channel
    pod5_channel = createChannelFromPod5Sheet(params.pod5_sheet)

    // Create a channel for the basecall model name
    basecall_model_ch = channel.value(params.basecall_model)

    // Combine POD5 files with model, reference genome index, and basecall model for basecalling
    pod5_files = pod5_channel
        .combine(model_path)
        .combine(ref_genome_index)
        .combine(basecall_model_ch)

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
    if (params.publish_fastq) {
        bamToFastq(merged_bams)
    }
}
