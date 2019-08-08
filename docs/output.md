# nf-ginkgo Output

**nf-ginkgo** is a pipeline for basic preprocessing of single cell WGS data.

This document describes the output produced by the pipeline.

## Pipeline overview:
The pipeline is built using [Nextflow](https://www.nextflow.io/)
and processes data using the following steps:

* [FastQC](#fastqc) - read quality control
* [TrimGalore](#trimgalore) - adapter trimming
* [BWA](#bwa) - alignment
* [SAMtools](#samtools) - alignment result processing
* [Bedtools](#bedtools) - bam to bed file conversion
* [Picard](#picard) - duplicate reads removal
* [Ginkgo](#ginkgo) - read binnning, single cell QC and heatmaps w/ clustering
* [MultiQC](#multiqc) - aggregate report, describing results of the whole pipeline

## FastQC
[FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/) gives general quality metrics about your reads. It provides information about the quality score distribution across your reads, the per base sequence content (%T/A/G/C). You get information about adapter contamination and other overrepresented sequences.

For further reading and documentation see the [FastQC help](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/Help/).

> **NB:** The FastQC plots displayed in the MultiQC report shows _untrimmed_ reads. They may contain adapter sequence and potentially regions with low quality. To see how your reads look after trimming, look at the FastQC reports in the `trim_galore` directory.

**Output directory: `results/fastqc`**

* `sample_fastqc.html`
  * FastQC report, containing quality metrics for your untrimmed raw fastq files
* `sample_fastqc.zip`
  * zip file containing the FastQC report, tab-delimited data file and plot images

## TrimGalore
[TrimGalore](http://www.bioinformatics.babraham.ac.uk/projects/trim_galore/) is used for removal of adapter contamination and trimming of low quality regions. TrimGalore uses [Cutadapt](https://github.com/marcelm/cutadapt) for adapter trimming and runs FastQC after it finishes.

MultiQC reports the percentage of bases removed by TrimGalore in the _General Statistics_ table, along with a line plot showing where reads were trimmed.

**Output directory: `results/trimgalore`**

Contains FastQ files with quality and adapter trimmed reads for each sample, along with a log file describing the trimming.

* `sample_val_1.fq.gz`, `sample_val_2.fq.gz`
  * Trimmed FastQ data, reads 1 and 2.
* `sample_val_1.fastq.gz_trimming_report.txt`
  * Trimming report (describes which parameters that were used)
* `sample_val_1_fastqc.html`
* `sample_val_1_fastqc.zip`
  * FastQC report for trimmed reads

Single-end data will have slightly different file names and only one FastQ file per sample:
* `sample_trimmed.fq.gz`
  * Trimmed FastQ data
* `sample.fastq.gz_trimming_report.txt`
  * Trimming report (describes which parameters that were used)
* `sample_trimmed_fastqc.html`
* `sample_trimmed_fastqc.zip`
  * FastQC report for trimmed reads

## BWA
[BWA](http://bio-bwa.sourceforge.net/), or Burrows-Wheeler Aligner, is designed for mapping low-divergent sequence reads against reference genomes. The result alignment files are further processed with [SAMtools](http://samtools.sourceforge.net/) and [Bedtools](http://bedtools.readthedocs.io/en/latest/).

**Output directory: `results/bwa`**

* `sample.bam`
  * The unsorted aligned BAM file (only when `--saveAlignedIntermediates`)
* `sample.sorted.bam`
  * The sorted aligned BAM file (only when `--saveAlignedIntermediates`)
* `sample.sorted.bam.bai`
  * The index file for aligned BAM file (only when `--saveAlignedIntermediates`)
* `mapped/mapped_regenome.txt`
  * Number of mapped and unmapped reads per sample (number of unmapped reads will be 0 unless you use the `--saveAlignedIntermediates` option
* `stats/sample.stats.txt`
  * output of `samtools stats` for each sample

## Picard
The [MarkDuplicates](https://broadinstitute.github.io/picard/command-line-overview.html#MarkDuplicates) module in the [Picard](https://broadinstitute.github.io/picard/) toolkit differentiates the primary and duplicate reads using an algorithm that ranks reads by the sums of their base-quality scores, which helps to identify duplicates that arise during sample preparation e.g. library construction using PCR.

The Picard section of the MultiQC report shows a bar plot with the numbers and proportions of primary reads, duplicate reads and unmapped reads.

![Picard](images/picard_plot.png)

**Output directory: `results/picard`**

* `sample.dedup.sorted.bam`
  * The sorted aligned BAM file after duplicate removal
* `sample.dedup.sorted.bam.bai`
  * The index file for aligned BAM file after duplicate removal
* `sample.dedup.sorted.bed`
  * The sorted aligned BED file after duplicate removal
* `sample.picardDupMetrics.txt`
  * The log report for duplicate removal

## Ginkgo
[Ginkgo](http://qb.cshl.edu/ginkgo) is a web tool for the analysis of single cell copy number data from whole-genome sequencing data. It was developed mainly by Robert Aboukhalil in Mike Schatz's lab. Further to the web interface, a CLI was made available. In essence, the genome is split into bins and the Ginkgo counts the number of reads within each bin. These numbers are mean-centered, GC corrected using a Lowess correction, Log2'ed, segmented with [DNAcopy](https://bioconductor.org/packages/release/bioc/html/DNAcopy.html), the best fit ploidy is estimated using a sweep search between 1.5 and 6 (in 0.05 intervals) and values are adjusted (rounded to the closest integer. Several QC plots and visualisattions are available for each sample.

**Output directory: `results/ginkgo`**

*Note: all the data are packaged into a file called `archive.tar.gz`*

* `data`
  * Table containing the raw read counts per bin per cell.
* `SegNorm`
  * Table containing the read counts after GC-lowess normalisation per bin per cell.
* `SegFixed`
  * Table containing the read counts after segmentation (before ploidy adjustement) per bin per cell.
* `SegCopy`
  * Final CN estiamates per bin per cell.
* `SegStats`
  * Final containing basic stats on read counts per bin for each cell (number of reads, variance, dispersion, etc).
* `sample_CN.jpeg`
  * Plot showing adjusted count data and copy number estimates along the genome
* `sample_counts.jpeg`
  * Histogram of read counts per bin
* `sample_dist.jpeg`
  * Plot showing raw read counts along the genome
* `sample_GC.jpeg`
  * Normalized read counts per bin vs bin GC content, before and after Lowess correction.
* `sample_hist.jpeg`
  * Histogram of CN estimates (adjusted for ploidy) before segmentation.
* `sample_lorenz.jpeg`
  * Lorenz stauration curve representing overage uniformity
* `sample_SoS.jpeg`
  * Sum of Squares error along potential ploidy numbers (1.5-6.0)
* `clust.jpeg`, `clust.newick`, `clust.pdf`, `clust.xml`
  * Clustering based on distances between cells using the `SegFixed` data
* `clust2.jpeg`, `clust2.newick`, `clust2.pdf`, `clust2.xml`
  * Clustering based on distances between cells using the `SegCopy` data
* `clust3.jpeg`, `clust3.newick`, `clust3.pdf`, `clust3.xml`
  * Clustering based on correlations between cells using the `SegCopy` data
* `heatCN.jpeg`, `heatCor.jpeg`, `heatNorm.jpeg`, `heatRaw.jpeg`
  * Heatmaps of the cells based on different data

## MultiQC
[MultiQC](http://multiqc.info) is a visualisation tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in within the report data directory.

**Output directory: `results/MultiQC`**

* `multiqc_report.html`
  * MultiQC report - a standalone HTML file that can be viewed in your web browser
* `multiqc_data/`
  * Directory containing parsed statistics from the different tools used in the pipeline

For more information about how to use MultiQC reports, see http://multiqc.info
