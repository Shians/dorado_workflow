// POD5 sheet parsing and validation functions following lupus_workflow conventions

// Parse POD5 sheet TSV file
// Expected columns: sample_id, path
// This will expand each path to find all .pod5 files
def parsePod5Sheet(pod5SheetPath) {
    def pod5Sheet = []
    def lineNumber = 0
    def errors = []

    file(pod5SheetPath).withReader { reader ->
        def header = null
        reader.eachLine { line ->
            lineNumber += 1

            // Skip empty lines
            if (line.trim().isEmpty()) {
                return
            }

            // Parse header
            if (header == null) {
                header = line.split('\t').collect { it.trim() }

                // Validate required columns
                def requiredCols = ['sample_id', 'path']
                def missingCols = requiredCols.findAll { !header.contains(it) }
                if (missingCols) {
                    errors << "ERROR: POD5 sheet missing required columns: ${missingCols.join(', ')}"
                    errors << "       Found columns: ${header.join(', ')}"
                    return
                }
                return
            }

            // Parse data rows
            def values = line.split('\t').collect { it.trim() }
            if (values.size() != header.size()) {
                errors << "ERROR: Line ${lineNumber} has ${values.size()} columns but header has ${header.size()} columns"
                return
            }

            def row = [header, values].transpose().collectEntries()

            // Validate sample_id
            if (!row.sample_id || row.sample_id.isEmpty()) {
                errors << "ERROR: Line ${lineNumber}: sample_id cannot be empty"
            }

            // Validate path exists
            if (!row.path || row.path.isEmpty()) {
                errors << "ERROR: Line ${lineNumber}: path cannot be empty"
            } else {
                def pod5Dir = file(row.path)
                if (!pod5Dir.exists()) {
                    errors << "ERROR: Line ${lineNumber}: POD5 directory does not exist: ${row.path}"
                } else if (!pod5Dir.isDirectory()) {
                    errors << "ERROR: Line ${lineNumber}: POD5 path is not a directory: ${row.path}"
                } else {
                    // Find all .pod5 files recursively in the directory
                    def pod5Files = []
                    pod5Dir.eachFileRecurse { file ->
                        if (file.isFile() && file.name.endsWith('.pod5')) {
                            pod5Files << file
                        }
                    }
                    if (pod5Files.isEmpty()) {
                        errors << "ERROR: Line ${lineNumber}: No POD5 files found in directory: ${row.path}"
                    }
                }
            }

            pod5Sheet << row
        }
    }

    if (errors.size() > 0) {
        log.error "POD5 sheet validation failed with ${errors.size()} error(s):"
        errors.each { error ->
            log.error "  ${error}"
        }
        System.exit(1)
    }

    if (pod5Sheet.size() == 0) {
        log.error "ERROR: POD5 sheet contains no data rows"
        System.exit(1)
    }

    return pod5Sheet
}

// Create a channel from POD5 sheet
// Returns a channel with tuples: [sample_id, pod5_file_path]
// Each POD5 file in each directory becomes a separate channel item for parallel processing
def createChannelFromPod5Sheet(pod5SheetPath) {
    def pod5Sheet = parsePod5Sheet(pod5SheetPath)

    // Expand directories to individual POD5 files
    def pod5FilesList = []
    pod5Sheet.each { row ->
        def pod5Dir = file(row.path)
        def pod5Files = []
        pod5Dir.eachFileRecurse { f ->
            if (f.isFile() && f.name.endsWith('.pod5')) {
                pod5Files << f
            }
        }
        pod5Files.each { pod5File ->
            pod5FilesList << [sample_id: row.sample_id, pod5_file: pod5File]
        }
    }

    // Log summary statistics
    def uniqueSamples = pod5FilesList.collect { it.sample_id }.unique()
    def pod5sBySample = pod5FilesList.groupBy { it.sample_id }.collectEntries { k, v -> [k, v.size()] }

    log.info "POD5 sheet loaded successfully:"
    log.info "  - Total POD5 files: ${pod5FilesList.size()}"
    log.info "  - Unique samples: ${uniqueSamples.size()}"
    log.info "  - Samples: ${uniqueSamples.join(', ')}"
    pod5sBySample.each { sample, count ->
        log.info "    ${sample}: ${count} POD5 files"
    }

    return channel.fromList(
        pod5FilesList.collect { row ->
            tuple(row.sample_id, file(row.pod5_file))
        }
    )
}
