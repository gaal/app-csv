#!perl -w

# Just make sure we can actually read and write actual files, and that
# our binary works.

use strict;
use warnings;
use Test::More;
BEGIN {
  eval "use Test::TempDir; 1" or do {
    plan skip_all => "Please install Test::TempDir";
    exit 0;
  };
  plan tests => 1;
}

use File::Spec;
use FindBin qw($Bin);

our $csv_bin = File::Spec->rel2abs(File::Spec->catfile($Bin, '..', 'bin', 'csv'));
our $infile = File::Spec->rel2abs(File::Spec->catfile($Bin, "input1.csv"));
our $expected_outfile = File::Spec->rel2abs(File::Spec->catfile($Bin, "output1.csv"));
my $outfile = File::Spec->catfile(temp_root(), 'output1.csv');
$outfile = File::Spec->rel2abs($outfile);

my @args = ("csv", libs(), $csv_bin,
    '--input' => $infile, '--output' => $outfile, 2, 1);
diag("$^X @args");
#system {"strace"} qw(-o /tmp/xx -e trace=open), $^X, @args and die "system: $!";
system {$^X} @args and die "system: $!";

diag("temporary output at $outfile");
is(slurp($outfile), slurp($expected_outfile),
    "actual commandline invocation produces correct results");

sub libs { map { ('-I' => $_) } @INC }
sub slurp { local $/; local @ARGV = pop; <> }
