process mergeBams {
    container 'ghcr.io/shians/lupus-workflow-container:main'

    publishDir "${params.output_dir}/basecalled/",
        mode: 'copy',
        enabled: params.publish.merged_bams

    cpus 8
    memory '32.GB'
    time '12h'
    tag "${sample_id}"

    input:
    tuple val(sample_id), path(bam_files, stageAs: "*.bam")

    output:
    tuple val(sample_id), path(merged_bam)

    script:
    merged_bam = "${sample_id}.bam"
    """
    samtools merge -@ ${task.cpus} -o ${merged_bam} ${bam_files}
    """
}

process bamToFastq {
    container 'ghcr.io/shians/lupus-workflow-container:main'

    publishDir "${params.output_dir}/fastq/",
        mode: 'copy',
        pattern: '*.fastq.gz',
        enabled: params.publish.fastq

    cpus 4
    memory '16.GB'
    time '12h'
    array 100
    tag "${sample_id}"

    input:
    tuple val(sample_id), path(bam_file)

    output:
    tuple val(sample_id), path(fastq_file)

    script:
    fastq_file = "${sample_id}.fastq.gz"
    """
    samtools fastq -F 0x900 -@ ${task.cpus} ${bam_file} | pigz -p ${task.cpus} > ${fastq_file}
    """
}
