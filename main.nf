#!/usr/bin/env nextflow
/*
========================================================================================
                         nf-core/ginkgo
========================================================================================
 nf-core/ginkgo Analysis Pipeline.
 #### Homepage / Documentation
 https://github.com/UCL-BLIC/nf-ginkgo
----------------------------------------------------------------------------------------
Pipeline overview:
 - 1:   FastQC for raw sequencing reads quality control
 - 2:   Trim Galore! for adapter trimming
 - 3.1: BWA alignment against reference genome
 - 3.2: Post-alignment processing and format conversion
 - 3.3: Statistics about mapped reads
 - 4:   Picard for duplicate read identification
 - 5:   Statistics about read counts
 - 6:   dedup BAMs to BigWigs
 - 7:   MultiQC
 - 8:   Output Description HTML
 ----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
*/


def helpMessage() {
    log.info"""
    =========================================
     nf-core/ginkgo v${workflow.manifest.version}
    =========================================
    Usage:

    The typical command for running the pipeline is as follows:

    nextflow_ginkgo --reads '*_R{1,2}.fastq.gz'

    Mandatory arguments:
      --reads                       Path to input data (must be surrounded with quotes) ['data/*{1,2}.fastq.gz']
      --genome                      Name of iGenomes reference (GRCh37) [GRCh37]

    Options:
      --singleEnd                   Specifies that the input is single end reads
      --allow_multi_align           Secondary alignments and unmapped reads are also reported in addition to primary alignments
      --ginkgo_bintype              Ginkgo counts reads in bins. Variable bins are adjusted for mappability (fixed, variable) [variable] 
      --read_length                 When using variable bin size, the read length affect the mappability adjustmente (48, 76, 101, 150) [76]
      --ginkgo_binsize              Bin size used by Ginkgo (5000, 10000, 25000, 50000, 100000, 175000, 250000, 500000,
                                    1000000, 2500000, 5000000, 10000000) [100000]

    References                      If not specified in the configuration file or you wish to overwrite any of the references.
      --fasta                       Path to Fasta reference
      --bwa_index                   Path to BWA index
      --saveAlignedIntermediates    Save the intermediate BAM files from the Alignment step  - not done by default

    Trimming options
      --notrim                      Specifying --notrim will skip the adapter trimming step.
      --saveTrimmed                 Save the trimmed Fastq files in the Results directory.
      --clip_r1 [int]               Instructs Trim Galore to remove bp from the 5' end of read 1 (or single-end reads)
      --clip_r2 [int]               Instructs Trim Galore to remove bp from the 5' end of read 2 (paired-end reads only)
      --three_prime_clip_r1 [int]   Instructs Trim Galore to remove bp from the 3' end of read 1 AFTER adapter/quality trimming has been performed
      --three_prime_clip_r2 [int]   Instructs Trim Galore to re move bp from the 3' end of read 2 AFTER adapter/quality trimming has been performed

    Other options:
      --outdir                      The output directory where the results will be saved [results]
      --email                       Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
      -name                         Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.
    """.stripIndent()
}

/*
 * SET UP CONFIGURATION VARIABLES
 */

// Show help emssage
if (params.help){
    helpMessage()
    exit 0
}


// Configurable variables
params.name = false
params.fasta = params.genome ? params.genomes[ params.genome ].fasta ?: false : false
params.bwa_index = params.genome ? params.genomes[ params.genome ].bwa ?: false : false
params.singleEnd = false 
params.notrim = false
params.saveTrimmed = false
params.saveAlignedIntermediates = false
params.allow_multi_align = false
params.multiqc_config = "$baseDir/conf/multiqc_config.yaml"
params.email = false
params.plaintext_email = false
params.ginkgo_binsize = 100000
params.read_length = 76
params.ginkgo_bintype = "variable"

multiqc_config = file(params.multiqc_config)
output_docs = file("$baseDir/docs/output.md")

// Custom trimming options
params.clip_r1 = 0
params.clip_r2 = 0
params.three_prime_clip_r1 = 0
params.three_prime_clip_r2 = 0

// Validate inputs
if ( params.fasta ){
    fasta = file(params.fasta)
    if( !fasta.exists() ) exit 1, "Fasta file not found: ${params.fasta}"
}
if( params.bwa_index ){
    bwa_index = Channel
        .fromPath(params.bwa_index)
        .ifEmpty { exit 1, "BWA index not found: ${params.bwa_index}" }
}


// Has the run name been specified by the user?
//  this has the bonus effect of catching both -name and --name
custom_runName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  custom_runName = workflow.runName
}


/*
 * Create a channel for input read files
 */
Channel
     .fromFilePairs( params.reads, size: params.singleEnd ? 1 : 2 )
     .ifEmpty { exit 1, "Cannot find any reads matching: ${params.reads}\nNB: Path needs to be enclosed in quotes!\nIf this is single-end data, please specify --singleEnd on the command line." }
     .into { read_files_fastqc; read_files_trimming }



// Header log info
log.info """=======================================================
                                          ,--./,-.
          ___     __   __   __   ___     /,-._.--~\'
    |\\ | |__  __ /  ` /  \\ |__) |__         }  {
    | \\| |       \\__, \\__/ |  \\ |___     \\`-._,-`-,
                                          `._,._,\'

nf-core/ginkgo v${workflow.manifest.version}"
======================================================="""
def summary = [:]
summary['Pipeline Name']  = 'nf-core/ginkgo'
summary['Pipeline Version'] = workflow.manifest.version
summary['Run Name']     = custom_runName ?: workflow.runName
summary['Reads']        = params.reads
summary['Genome']       = params.genome
summary['Fasta Ref']    = params.fasta
summary['BWA Index']    = params.bwa_index
summary['Data Type']    = params.singleEnd ? 'Single-End' : 'Paired-End'
summary['Save Trimmed']        = params.saveTrimmed
summary['Save Intermeds']      = params.saveAlignedIntermediates
if( params.notrim ){
    summary['Trimming Step'] = 'Skipped'
} else {
    summary['Trim R1'] = params.clip_r1
    summary['Trim R2'] = params.clip_r2
    summary["Trim 3' R1"] = params.three_prime_clip_r1
    summary["Trim 3' R2"] = params.three_prime_clip_r2
}
summary['Max Memory']   = params.max_memory
summary['Max CPUs']     = params.max_cpus
summary['Max Time']     = params.max_time
summary['Output dir']   = params.outdir
summary['Working dir']  = workflow.workDir
summary['Container Engine'] = workflow.containerEngine
if(workflow.containerEngine) summary['Container'] = workflow.container
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Working dir']    = workflow.workDir
summary['Output dir']     = params.outdir
summary['Script dir']     = workflow.projectDir
summary['Config Profile'] = workflow.profile
if(params.email) summary['E-mail Address'] = params.email
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="


def create_workflow_summary(summary) {

    def yaml_file = workDir.resolve('workflow_summary_mqc.yaml')
    yaml_file.text  = """
    id: 'nf-core-ginkgo-summary'
    description: " - this information is collected when the pipeline is started."
    section_name: 'nf-core/ginkgo Workflow Summary'
    section_href: 'https://github.com/UCL-BLIC/nf-ginkgo'
    plot_type: 'html'
    data: |
        <dl class=\"dl-horizontal\">
${summary.collect { k,v -> "            <dt>$k</dt><dd><samp>${v ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>" }.join("\n")}
        </dl>
    """.stripIndent()

   return yaml_file
}



/*
 * STEP 1 - FastQC
 */
process fastqc {
    tag "$name"
    publishDir "${params.outdir}/fastqc", mode: 'copy',
        saveAs: {filename -> filename.indexOf(".zip") > 0 ? "zips/$filename" : "$filename"}

    input:
    set val(name), file(reads) from read_files_fastqc

    output:
    file "*_fastqc.{zip,html}" into fastqc_results

    script:
    """
    fastqc -q $reads
    """
}


/*
 * STEP 2 - Trim Galore!
 */
if(params.notrim){
    trimmed_reads = read_files_trimming
    trimgalore_results = []
    trimgalore_fastqc_reports = []
} else {
    process trim_galore {
        tag "$name"
        publishDir "${params.outdir}/trim_galore", mode: 'copy',
            saveAs: {filename ->
                if (filename.indexOf("_fastqc") > 0) "FastQC/$filename"
                else if (filename.indexOf("trimming_report.txt") > 0) "logs/$filename"
                else params.saveTrimmed ? filename : null
            }

        input:
        set val(name), file(reads) from read_files_trimming

        output:
        file '*.fq.gz' into trimmed_reads
        file '*trimming_report.txt' into trimgalore_results
        file "*_fastqc.{zip,html}" into trimgalore_fastqc_reports

        script:
        c_r1 = params.clip_r1 > 0 ? "--clip_r1 ${params.clip_r1}" : ''
        c_r2 = params.clip_r2 > 0 ? "--clip_r2 ${params.clip_r2}" : ''
        tpc_r1 = params.three_prime_clip_r1 > 0 ? "--three_prime_clip_r1 ${params.three_prime_clip_r1}" : ''
        tpc_r2 = params.three_prime_clip_r2 > 0 ? "--three_prime_clip_r2 ${params.three_prime_clip_r2}" : ''
        if (params.singleEnd) {
            """
            trim_galore --fastqc --gzip $c_r1 $tpc_r1 $reads
            """
        } else {
            """
            trim_galore --paired --fastqc --gzip $c_r1 $c_r2 $tpc_r1 $tpc_r2 $reads
            """
        }
    }
}


/*
 * STEP 3.1 - align with bwa
 */
process bwa {
    tag "$prefix"
    publishDir path: { params.saveAlignedIntermediates ? "${params.outdir}/bwa" : params.outdir }, mode: 'copy',
               saveAs: {filename -> params.saveAlignedIntermediates ? filename : null }

    input:
    file reads from trimmed_reads
    file index from bwa_index.first()

    output:
    file '*.bam' into bwa_bam

    script:
    prefix = reads[0].toString() - ~/(.R1)?(_1)?(_R1)?(_trimmed)?(_val_1)?(\.fq)?(\.fastq)?(\.gz)?$/
    filtering = params.allow_multi_align ? '' : "| samtools view -b -q 1 -F 4 -F 256"
    """
    bwa mem -M ${index}/genome.fa $reads | samtools view -bT $index - $filtering > ${prefix}.bam
    """
}


/*
 * STEP 3.2 - post-alignment processing
 */

process samtools {
    tag "${bam.baseName}"
    publishDir path: "${params.outdir}/bwa", mode: 'copy',
               saveAs: { filename ->
                   if (filename.indexOf(".stats.txt") > 0) "stats/$filename"
                   else params.saveAlignedIntermediates ? filename : null
               }

    input:
    file bam from bwa_bam

    output:
    file '*.sorted.bam' into bam_picard, bam_for_mapped
    file '*.sorted.bam.bai' into bwa_bai, bai_for_mapped
    file '*.stats.txt' into samtools_stats

    script:
    """
    samtools sort $bam -o ${bam.baseName}.sorted.bam
    samtools index ${bam.baseName}.sorted.bam
    samtools stats ${bam.baseName}.sorted.bam > ${bam.baseName}.stats.txt
    """
}


/*
 * STEP 3.3 - Statistics about mapped and unmapped reads against ref genome
 */

process bwa_mapped {
    tag "${input_files[0].baseName}"
    publishDir "${params.outdir}/bwa/mapped", mode: 'copy'

    input:
    file input_files from bam_for_mapped.collect()
    file bai from bai_for_mapped.collect()

    output:
    file 'mapped_refgenome.txt' into bwa_mapped

    script:
    """
    for i in $input_files
    do
      samtools idxstats \${i} | awk -v filename="\${i}" '{mapped+=\$3; unmapped+=\$4} END {print filename,"\t",mapped,"\t",unmapped}'
    done > mapped_refgenome.txt
    """
}

/*
 * STEP 4 Picard
 */

process picard {
    tag "$prefix"
    publishDir "${params.outdir}/picard", mode: 'copy'

    input:
    file bam from bam_picard

    output:
    file '*.dedup.sorted.bam' into bam_dedup_spp, bam_dedup_ngsplot, bam_dedup_deepTools, bam_dedup_macs, bam_dedup_saturation, bam_dedup_bigwigs
    file '*.dedup.sorted.bam.bai' into bai_dedup_deepTools, bai_dedup_ngsplot, bai_dedup_macs, bai_dedup_saturation, bai_dedup_bigwigs
    file '*.dedup.sorted.bed.gz' into bed_dedup
    file '*.picardDupMetrics.txt' into picard_reports

    script:
    prefix = bam[0].toString() - ~/(\.sorted)?(\.bam)?$/
    if( !task.memory ){
        log.warn "[Picard MarkDuplicates] Available memory not known - defaulting to 6GB ($prefix)"
        avail_mem = 6000
    } else {
        avail_mem = task.memory.toMega()
        if( avail_mem <= 0){
            avail_mem = 6000
            log.warn "[Picard MarkDuplicates] Available memory 0 - defaulting to 6GB ($prefix)"
        } else if( avail_mem < 250){
            avail_mem = 250
            log.warn "[Picard MarkDuplicates] Available memory under 250MB - defaulting to 250MB ($prefix)"
        }
    }
    """
    picard MarkDuplicates \\
        INPUT=$bam \\
        OUTPUT=${prefix}.dedup.bam \\
        ASSUME_SORTED=true \\
        REMOVE_DUPLICATES=true \\
        METRICS_FILE=${prefix}.picardDupMetrics.txt \\
        VALIDATION_STRINGENCY=LENIENT \\
        PROGRAM_RECORD_ID='null'
    samtools sort ${prefix}.dedup.bam -o ${prefix}.dedup.sorted.bam
    samtools index ${prefix}.dedup.sorted.bam
    bedtools bamtobed -i ${prefix}.dedup.sorted.bam | sort -k 1,1 -k 2,2n -k 3,3n -k 6,6 | gzip - > ${prefix}.dedup.sorted.bed.gz
    """
}


/*
 * STEP 5 Create bigWigs
 */

process bigwigs {
    tag "$prefix"
    publishDir "${params.outdir}/bigwigs", mode: 'copy'

    input:
    file bam from bam_dedup_bigwigs
    file bai from bai_dedup_bigwigs

    output:
    file '*.bw'

    script:
    prefix = bam[0].toString() - ~/(\.dedup)?(\.sorted)?(\.bam)?$/
    fasta=params.fasta
    fastafai="${fasta}.fai"
    """
    bedtools genomecov -bg -ibam $bam -g $fastafai > ${prefix}.bdg
    LC_COLLATE=C sort -k1,1 -k2,2n ${prefix}.bdg > ${prefix}.sorted.bdg
    bedGraphToBigWig ${prefix}.sorted.bdg $fastafai ${prefix}.bw
    """
}

/*
 * STEP 6 Ginkgo
 */

process ginkgo {
    publishDir "${params.outdir}/ginkgo", mode: 'copy'

    input:
    file bed_files from bed_dedup.collect()

    output:
    file '*.tar.gz'

    script:
    """
    # Rename the bed files to remove the *.dedup.sorted.bed.gz *.bed.gz
    for bed in $bed_files; do mv \$bed \${bed//.dedup.sorted}; done

    # Only add to list the files that are large enough (empty or nearly empty libraries break Ginkgo)
    ls *.bed.gz | while read f; do ls -Ls \$f ; done | awk '\$1 > 1000 {print \$2}' > list

    # Run Ginkgo
    ginkgo.sh --input \$PWD --genome hg19 --binning ${params.ginkgo_bintype}_${params.ginkgo_binsize}_${params.read_length}_bwa --cells list --maskbadbins
    """
}

/*
 * Parse software version numbers
 */
process get_software_versions {

    output:
    file 'software_versions_mqc.yaml' into software_versions_yaml

    script:
    """
    echo $workflow.manifest.version > v_ngi_chipseq.txt
    echo $workflow.nextflow.version > v_nextflow.txt
    fastqc --version > v_fastqc.txt
    trim_galore --version > v_trim_galore.txt
    echo \$(bwa 2>&1) > v_bwa.txt
    samtools --version > v_samtools.txt
    bedtools --version > v_bedtools.txt
    echo "version" \$(java -Xmx2g -jar \$PICARD_HOME/picard.jar MarkDuplicates --version 2>&1) >v_picard.txt
    multiqc --version > v_multiqc.txt
    scrape_software_versions.py > software_versions_mqc.yaml
    """
}

/*
 * STEP 6 - MultiQC
 */
process multiqc {
    publishDir "${params.outdir}/MultiQC", mode: 'copy'

    input:
    file multiqc_config
    file ('fastqc/*') from fastqc_results.collect()
    file ('trimgalore/*') from trimgalore_results.collect()
    file ('samtools/*') from samtools_stats.collect()
    file ('picard/*') from picard_reports.collect()
    file ('software_versions/*') from software_versions_yaml
    file workflow_summary from create_workflow_summary(summary)

    output:
    file "*multiqc_report.html" into multiqc_report
    file "*_data"

    script:
    rtitle = custom_runName ? "--title \"$custom_runName\"" : ''
    rfilename = custom_runName ? "--filename " + custom_runName.replaceAll('\\W','_').replaceAll('_+','_') + "_multiqc_report" : ''
    """
    multiqc -f $rtitle $rfilename --config $multiqc_config .
    """
}


/*
 * STEP 7 - Output Description HTML
 */
process output_documentation {
    tag "$prefix"
    publishDir "${params.outdir}/Documentation", mode: 'copy'

    input:
    file output_docs

    output:
    file "results_description.html"

    script:
    """
    markdown_to_html.r $output_docs results_description.html
    """
}



/*
 * Completion e-mail notification
 */
workflow.onComplete {

    // Set up the e-mail variables
    def subject = "[nf-core/ginkgo] Successful: $workflow.runName"
    if(!workflow.success){
      subject = "[nf-core/ginkgo] FAILED: $workflow.runName"
    }
    def email_fields = [:]
    email_fields['version'] = workflow.manifest.version
    email_fields['runName'] = custom_runName ?: workflow.runName
    email_fields['success'] = workflow.success
    email_fields['dateComplete'] = workflow.complete
    email_fields['duration'] = workflow.duration
    email_fields['exitStatus'] = workflow.exitStatus
    email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
    email_fields['errorReport'] = (workflow.errorReport ?: 'None')
    email_fields['commandLine'] = workflow.commandLine
    email_fields['projectDir'] = workflow.projectDir
    email_fields['summary'] = summary
    email_fields['summary']['Date Started'] = workflow.start
    email_fields['summary']['Date Completed'] = workflow.complete
    email_fields['summary']['Pipeline script file path'] = workflow.scriptFile
    email_fields['summary']['Pipeline script hash ID'] = workflow.scriptId
    if(workflow.repository) email_fields['summary']['Pipeline repository Git URL'] = workflow.repository
    if(workflow.commitId) email_fields['summary']['Pipeline repository Git Commit'] = workflow.commitId
    if(workflow.revision) email_fields['summary']['Pipeline Git branch/tag'] = workflow.revision
    email_fields['summary']['Nextflow Version'] = workflow.nextflow.version
    email_fields['summary']['Nextflow Build'] = workflow.nextflow.build
    email_fields['summary']['Nextflow Compile Timestamp'] = workflow.nextflow.timestamp

    // Render the TXT template
    def engine = new groovy.text.GStringTemplateEngine()
    def tf = new File("$baseDir/assets/email_template.txt")
    def txt_template = engine.createTemplate(tf).make(email_fields)
    def email_txt = txt_template.toString()

    // Render the HTML template
    def hf = new File("$baseDir/assets/email_template.html")
    def html_template = engine.createTemplate(hf).make(email_fields)
    def email_html = html_template.toString()

    // Render the sendmail template
    def smail_fields = [ email: params.email, subject: subject, email_txt: email_txt, email_html: email_html, baseDir: "$baseDir" ]
    def sf = new File("$baseDir/assets/sendmail_template.txt")
    def sendmail_template = engine.createTemplate(sf).make(smail_fields)
    def sendmail_html = sendmail_template.toString()

    // Send the HTML e-mail
    if (params.email) {
        try {
          if( params.plaintext_email ){ throw GroovyException('Send plaintext e-mail, not HTML') }
          // Try to send HTML e-mail using sendmail
          [ 'sendmail', '-t' ].execute() << sendmail_html
          log.info "[nf-core/ginkgo] Sent summary e-mail to $params.email (sendmail)"
        } catch (all) {
          // Catch failures and try with plaintext
          [ 'mail', '-s', subject, params.email ].execute() << email_txt
          log.info "[nf-core/ginkgo] Sent summary e-mail to $params.email (mail)"
        }
    }

    // Write summary e-mail HTML to a file
    def output_d = new File( "${params.outdir}/Documentation/" )
    if( !output_d.exists() ) {
      output_d.mkdirs()
    }
    def output_hf = new File( output_d, "pipeline_report.html" )
    output_hf.withWriter { w -> w << email_html }
    def output_tf = new File( output_d, "pipeline_report.txt" )
    output_tf.withWriter { w -> w << email_txt }

    log.info "[nf-core/ginkgo] Pipeline Complete"

}
