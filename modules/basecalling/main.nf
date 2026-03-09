process doradoDownloadModel {
    label 'small'

    input:
    val(model_names)

    output:
    path(model_path)

    script:
    model_path = "dorado_models/"
    def cmds = model_names.collect { name -> "dorado download --model ${name} --models-directory ${model_path}" }.join('\n    ')
    """
    mkdir -p ${model_path}
    ${cmds}
    """
}

process doradoBaseCall {
    label 'large'

    array 100
    tag "${sample_id}-${pod5_file.simpleName}"

    errorStrategy { task.exitStatus in 137..143 ? 'retry' : 'terminate' }
    maxRetries 3

    input:
    tuple val(sample_id), path(pod5_file), path(model), path(ref_genome), val(model_shorthand), val(mod_code), val(mm2_preset)

    output:
    tuple val(sample_id), path("${bam_folder}/**/*.bam")

    script:
    bam_folder = "dorado_output/${sample_id}"
    mod_bases_arg = mod_code ? "--modified-bases \"${mod_code}\"" : ""
    """
    mkdir -p ${bam_folder}
    dorado basecaller \
        --reference ${ref_genome} \
        --mm2-opts "-x ${mm2_preset}" \
        --models-directory ${model} \
        --output-dir ${bam_folder} \
        ${mod_bases_arg} \
        ${model_shorthand} \
        ${pod5_file}
    """
}
