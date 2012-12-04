use strict;
use warnings;

require 5.006;

use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME  => 'App-CSV',
  NAME      => 'App::CSV',
  AUTHOR    => 'Gaal\ Yahas\ \<gaal\@forum2\.org\>',
  ABSTRACT  => 'Manipulate CSV files from the command line',
  VERSION_FROM => 'lib/App/CSV.pm',
  MIN_PERL_VERSION => 'v5.6.0',
  SIGN => 1,
  EXE_FILES => [ grep { /\w$/ } glob("bin/*") ],
  (eval { ExtUtils::MakeMaker->VERSION(6.21) } ? (LICENSE => 'mit') : ()),
  PREREQ_PM    => {
    (eval { require Text::CSV_XS } ? ("Text::CSV_XS" => 0)
                                   : ("Text::CSV" => 0)),
    'Moose' => 0,
    'MooseX::Getopt' => 0,

    # Testing
    'IO::String' => 0,

    # Recommended
    # 'Temp::TestDir' => 0,
    # 'IPC::Run' => 0,
  },
);
