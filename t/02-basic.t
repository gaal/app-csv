#!perl -T

use strict;
use warnings;
use Test::More tests => 4;

use App::CSV;
use IO::String;

my $input = <<'.';
"1","2","3"
11,22,33
111,222,333
.

sub setup {
  local @ARGV = @_;
  my $output_fh = IO::String->new;
  my $ac = App::CSV->new_with_options;
  $ac->_input_fh(IO::String->new($input));
  $ac->_output_fh($output_fh);
  return($ac, $output_fh->string_ref);
}

{
  my($ac, $output) = setup(2);  # "csv 2"
  $ac->init;
  is_deeply($ac->columns, [1], "column normalization");
  $ac->run;
  is($$output, "2\n22\n222\n", "1-based, single column");
}

{
  my($ac, $output) = setup(1, -1);  # "csv 1 -1"
  $ac->init;
  is_deeply($ac->columns, [0, -1], "column normalization");
  $ac->run;
  is($$output, "1,3\n11,33\n111,333\n", "1-based, two columns, negative columns");
}
