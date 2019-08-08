#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long;

my $ginkgo_home = $ENV{GINKGO_HOME};
my $genome = "hg19";
my $bin_type = "variable";
my $bin_size = 100000;
my $aligner = "bwa";

GetOptions(
 "ginkgo_home=s" => \$ginkgo_home,
 "genome=s" => \$genome,
 "bin_type=s" => \$bin_type,
 "bin_size=i" => \$bin_size,
 "aligner=s" => \$aligner);
my @bed_files = @ARGV;

opendir(DIR, "$ginkgo_home/genomes/$genome/original/") or die "Cannot open dir $ginkgo_home/genomes/$genome/original/: $!";
my @genome_files = grep { /^${bin_type}_${bin_size}_\d*_${aligner}/ } readdir(DIR);
closedir(DIR);

# print join(" ", @genome_files), "\n";
my @available_read_lengths = map {s/^${bin_type}_${bin_size}_(\d*)_${aligner}/$1/; $_} @genome_files;
# print "AVAIL: ", join(" ", @available_read_lengths), "\n";

my $runstr = "ls " . join(" ", @bed_files). ' | while read f; do gunzip -c $f | head -n 1000 | '.
  'awk \'{print $3 - $2 + 1}\'; done | sort -n | uniq -c | sort -nr | head -n 1 | awk \'{print $2}\'';

my $most_common_read_length = qx"$runstr";
# print "COMMON: ", join(" ", @most_common_read_lengths), "\n";

my $best_read_length = 0;
my $best_fit = 1e10;
foreach my $this_avail_length (@available_read_lengths) {
  my $fit = 0;
  $fit += abs($this_avail_length - $most_common_read_length);
  if ($fit < $best_fit) {
    $best_fit = $fit;
    $best_read_length = $this_avail_length;
  }
  # print join(" ", $this_avail_length, $fit, $best_fit, $best_read_length), "\n";
}

print $best_read_length, "\n";

