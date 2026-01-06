process doradoDownloadModel {
    container 'oras://ghcr.io/shians/dorado-container:1.1.1-singularity'

    cpus 4
    memory '8.GB'
    time '1h'

    input:
    val(model_name)

    output:
    path(model_path)

    script:
    model_path = "dorado_models/"
    """
    mkdir -p ${model_path}
    dorado download --model ${model_name} --models-directory ${model_path}
    """
}

process doradoBaseCall {
    container 'oras://ghcr.io/shians/dorado-container:1.1.1-singularity'

    executor 'slurm'
    cpus 24
    memory '128.GB'
    time '4h'
    queue 'gpuq'
    clusterOptions '--gres=gpu:A30:1'
    array 100
    tag "${sample_id}-${pod5_file.simpleName}"

    errorStrategy { task.exitStatus in 137..143 ? 'retry' : 'terminate' }
    maxRetries 3

    input:
    tuple val(sample_id), path(pod5_file), path(model), path(ref_genome), val(basecall_model)

    output:
    tuple val(sample_id), path("${bam_folder}/**/*.bam")

    script:
    bam_folder = "dorado_output/${sample_id}"
    model_dir = "${model}/${basecall_model}"
    """
    mkdir -p ${bam_folder}
    dorado basecaller \
        --reference ${ref_genome} \
        --output-dir ${bam_folder} \
        ${model_dir} \
        ${pod5_file}
    """
}
