process buildMinimapIndexGenome {
    label 'medium'

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
