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

    minimap2_preset = params.cdna ? 'splice:hq' : 'lr:hq'

    // Detect if basecall_model includes a modification model (two '@' signs)
    def model_parts = params.basecall_model.tokenize('@')
    def is_mod_model = model_parts.size() > 2
    def base_model_name = is_mod_model ? model_parts[0] + '@' + model_parts[1].tokenize('_')[0] : params.basecall_model
    def models_to_download = is_mod_model ? [base_model_name, params.basecall_model] : [params.basecall_model]

    // Extract shorthand model (e.g., sup@v5.2.0) and modification code (e.g., 5mCG_5hmCG)
    def accuracy = model_parts[0].tokenize('_').last()
    def version = model_parts[1].tokenize('_')[0]
    def model_shorthand = accuracy + '@' + version
    def mod_code = is_mod_model ? model_parts[1].tokenize('_')[1..-1].join('_') : ''

    // Download Dorado model(s)
    model_path = doradoDownloadModel(channel.value(models_to_download))

    // Get reference genome path
    ref_genome_path = channel.fromPath(params.reference_genome)

    // Build minimap2 index for genome (optional, for alignment during basecalling)
    ref_genome_index = buildMinimapIndexGenome(ref_genome_path, channel.value(minimap2_preset))

    // Parse POD5 sheet and create channel
    pod5_channel = createChannelFromPod5Sheet(params.pod5_sheet)

    // Combine POD5 files with model directory, reference, model shorthand, mod code, and mm2 preset
    pod5_files = pod5_channel
        .combine(model_path)
        .combine(ref_genome_index)
        .combine(channel.value(model_shorthand))
        .combine(channel.value(mod_code))
        .combine(channel.value(minimap2_preset))

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
