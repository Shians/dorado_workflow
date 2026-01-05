// Parameter validation functions following lupus_workflow conventions

def validateFileParam(errors, paramValue, paramName, displayName) {
    if (!paramValue) {
        errors << "ERROR: ${paramName} is not defined"
        return
    }

    if (paramValue instanceof String && paramValue.trim().isEmpty()) {
        errors << "ERROR: ${paramName} is an empty string"
        return
    }

    def fileObj = file(paramValue)

    if (!fileObj.exists()) {
        errors << "ERROR: ${displayName} does not exist: ${paramValue}"
        return
    }

    if (!fileObj.isFile()) {
        errors << "ERROR: ${displayName} is not a file: ${paramValue}"
        return
    }

    if (fileObj.isEmpty()) {
        errors << "ERROR: ${displayName} is empty: ${paramValue}"
        return
    }
}

def validateParams() {
    def errors = []

    // Validate required file parameters
    validateFileParam(errors, params.pod5_sheet, "params.pod5_sheet", "POD5 sheet file")
    validateFileParam(errors, params.reference_genome, "params.reference_genome", "Reference genome file")

    // Validate basecall_model parameter
    if (!params.basecall_model) {
        errors << "ERROR: params.basecall_model is not defined"
        errors << "       Example: --basecall_model dna_r10.4.1_e8.2_400bps_sup@v5.0.0"
    } else if (params.basecall_model instanceof String && params.basecall_model.trim().isEmpty()) {
        errors << "ERROR: params.basecall_model is an empty string"
    }

    // Report errors if any
    if (errors.size() > 0) {
        log.error "Parameter validation failed with ${errors.size()} error(s):"
        errors.each { error ->
            log.error "  ${error}"
        }
        System.exit(1)
    }

    // Success message
    log.info "✓ Parameter validation successful"
    log.info "  - POD5 sheet: ${params.pod5_sheet}"
    log.info "  - Reference genome: ${params.reference_genome}"
    log.info "  - Basecalling model: ${params.basecall_model}"
    log.info "  - Output directory: ${params.output_dir}"
}
