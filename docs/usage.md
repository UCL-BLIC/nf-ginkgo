# nf-core/ginkgo: Usage

## Table of contents

* [Running the pipeline](#running-the-pipeline)
* [Main arguments](#main-arguments)
    * [`-profile`](#-profile-single-dash)
        * [`legion`](#docker)
        * [`myriad`](#awsbatch)
    * [`--reads`](#--reads)
    * [`--singleEnd`](#--singleend)
    * [`--ginkgo_bintype`](#--ginkgo_bintype)
    * [`--read_length`](#--read_length)
    * [`--ginkgo_binsize`](#--ginkgo_binsize)
* [Reference Genomes](#reference-genomes)
    * [`--genome`](#--genome)
    * [`--fasta`](#--fasta)
* [Job Resources](#job-resources)
* [Automatic resubmission](#automatic-resubmission)
* [Other command line parameters](#other-command-line-parameters)
    * [`--outdir`](#--outdir)
    * [`--email`](#--email)
    * [`-name`](#-name-single-dash)
    * [`-resume`](#-resume-single-dash)
    * [`--max_memory`](#--max_memory)
    * [`--max_time`](#--max_time)
    * [`--max_cpus`](#--max_cpus)
    * [`--plaintext_emails`](#--plaintext_emails)
    * [`--multiqc_config`](#--multiqc_config)


## Running the pipeline
The typical command for running the pipeline is as follows:
```bash
module load blic-modules
module load nextflow
module load ginkgo

nextflow_ginkgo --reads '*_R{1,2}.fastq.gz'
```

This will launch the pipeline with the `legion` or `myriad` configuration profile, depending on where you submit the job from.

Note that the pipeline will create the following files in your working directory:

```bash
work            # Directory containing the nextflow working files
results         # Finished results (configurable, see below)
.nextflow_log   # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

## Main Arguments

To see all the available arguments, use the `--help` flag
```bash
nextflow_ginkgo --help
```

The main arguments are:

### `-profile`
This parameter is NOT necessary as the shortcut `nextflow_ginkgo` takes care of selecting the appropiate configuration profile. But just for your information, profiles are used to give 
configuration presets for different compute environments.

* `legion`
    * A generic configuration profile to be used with the UCL cluster legion
* `myriad`
    * A generic configuration profile to be used with the UCL cluster myriad

### `--reads`
Use this to specify the location of your input FastQ files. For example:

```bash
--reads 'path/to/data/sample_*_{1,2}.fastq'
```

Please note the following requirements:

1. The path must be enclosed in quotes
2. The path must have at least one `*` wildcard character
3. When using the pipeline with paired end data, the path must use `{1,2}` notation to specify read pairs.

If left unspecified, a default pattern is used: `data/*{1,2}.fastq.gz`

### `--singleEnd`
By default, the pipeline expects paired-end data. If you have single-end data, you need to specify `--singleEnd` on the command line when you launch the pipeline. A normal glob pattern, enclosed in quotation marks, can then be used for `--reads`. For example:

```bash
--singleEnd --reads '*.fastq'
```

It is not possible to run a mixture of single-end and paired-end files in one run.

### `--ginkgo_bintype`
Ginkgo counts reads in bins of predefined size (see [`--ginkgo_binsize`](#--ginkgo_binsize) for available sizes). Two types of bins are available: `fixed` and `variable`.

* `fixed`
    * Bins have all the same size
* `variable` [default]
    * Bins are adjusted for mappability along the genome.


### `--read_length`
Pre-calculated variable length in Ginkgo are adjusted for mappability. As the mappability depends on the read length, this option allows you to select the most appropriate read length for your library. This value is ignored if you use fixed length bins. Possible values are: `48`, `76`, `101`, `150`.

The default read length is `76`.


### `--ginkgo_binsize`
Provided with Ginkgo are pre-calculated genome bins of either fixed or variable length (see [`--ginkgo_bintype`](#--ginkgo_bintype) for more info). For the GRCh37 human reference genome (referred as hg19 by Ginkgo), the possible bin sizes are: `5000`, `10000`, `25000`, `50000`, `100000`, `175000`, `250000`, `500000`, `1000000`, `2500000`, `5000000`, `10000000`.

The default bin size is `100000`.

## Reference Genomes

While the pipeline is based on the nf-core/ginkgo pipeline and that accept several reference genome assemblies, you are limited to GRCh37 with Ginkgo. If you wanted to use a different one, you would have to specify it with the `--genome` flag.

* Human
  * `--genome GRCh37`
* Mouse


```bash
--fasta '[path to Fasta reference]'
```

## Job Resources
### Automatic resubmission
Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with an error code of `143` (exceeded requested resources) it will automatically resubmit with higher requests (2 x original, then 3 x original). If it still fails after three times then the pipeline is stopped.

## Other command line parameters

### `--outdir`
The output directory where the results will be saved.

### `--email`
Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits. If set in your user config file (`~/.nextflow/config`) then you don't need to speicfy this on the command line for every run.

### `-name`
Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.

This is used in the MultiQC report (if not default) and in the summary HTML / e-mail (always).

**NB:** Single hyphen (core Nextflow option)

### `-resume`
Specify this when restarting a pipeline. Nextflow will used cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously.

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

**NB:** Single hyphen (core Nextflow option)

### `--max_memory`
Use to set a top-limit for the default memory requirement for each process.
Should be a string in the format integer-unit. eg. `--max_memory '8.GB'`

### `--max_time`
Use to set a top-limit for the default time requirement for each process.
Should be a string in the format integer-unit. eg. `--max_time '2.h'`

### `--max_cpus`
Use to set a top-limit for the default CPU requirement for each process.
Should be a string in the format integer-unit. eg. `--max_cpus 1`

### `--plaintext_email`
Set to receive plain-text e-mails instead of HTML formatted.

### `--multiqc_config`
Specify a path to a custom MultiQC configuration file.

