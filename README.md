# nf-core/ginkgo
**Nextflow pipeline for Ginkgo (scWGS)**

[![Build Status](https://travis-ci.org/nf-core/ginkgo.svg?branch=master)](https://travis-ci.org/nf-core/ginkgo)
[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A50.32.0-brightgreen.svg)](https://www.nextflow.io/)


### Introduction
The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner.

[Ginkgo](http://qb.cshl.edu/ginkgo) is a web tool for the analysis of single cell copy number data from whole-genome sequencing data. It was developed mainly by Robert Aboukhalil in Mike Schatz's lab. Further to the web interface, a CLI was made available.

This pipeline runs:
1. FastQC for raw sequencing reads quality control
2. TrimGalore! for adapter trimming
3. bwa to align the reads on the genome
4. samtools for sorting, indexing and getting stats
5. Picard MarkDuplicates, sort, index and BED files
6. BigWigs for display on a browser
7. Ginkgo for the normalisation, segmentation and QC of the single cell libraries
8. MultiQC (does not cover Ginkgo QC)
9. Output Description HTML

### Documentation
The nf-ginkgo pipeline is based on the nf-core/ginkgo pipeline. It comes with documentation about the pipeline, found in the `docs/` directory:

1. [Installation](docs/installation.md)
2. [Running the pipeline](docs/usage.md)
3. [Output and how to interpret the results](docs/output.md)
4. [Troubleshooting](docs/troubleshooting.md)
