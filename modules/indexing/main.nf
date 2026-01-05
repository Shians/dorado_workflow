process buildMinimapIndexGenome {
    container 'oras://ghcr.io/shians/lupus-workflow-container:latest-singularity'

    cpus 8
    memory '64.GB'
    time '12h'

    input:
    path(ref_genome)

    output:
    path(index_mmi)

    script:
    index_mmi = "${ref_genome}.mmi"
    """
    minimap2 -x splice:hq -d ${index_mmi} ${ref_genome}
    """
}
