process buildMinimapIndexGenome {
    label 'medium'

    input:
    path(ref_genome)
    val(preset)

    output:
    path(index_mmi)

    script:
    index_mmi = "${ref_genome}.mmi"
    """
    minimap2 -x ${preset} -d ${index_mmi} ${ref_genome}
    """
}
