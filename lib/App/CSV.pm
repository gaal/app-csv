package App::CSV;

use Moose;
use IO::Handle;
use Text::CSV;

our $VERSION = '0.01';

BEGIN {
  # One day, MooseX::Getopt will allow us to pass pass_through to Getopt::Long.
  # Until then, do the following ugly thing unconditionally.
  # (We don't need a BEGIN block here yet. But we will once we start fussing
  # around with version numbers.)
  use Getopt::Long qw(:config pass_through);
}

with 'MooseX::Getopt';

sub hasrw {
  my($attr, @args) = @_;
  has $attr => (
    is => 'rw',
    @args,
  );
}

hasrw input => (isa => 'Str');

hasrw output => (isa => 'Str');

# isa => 'FileHandle' (or IO::String...)
hasrw _input_fh => (
);

# isa => 'FileHandle' (or IO::String...)
hasrw _output_fh => ();

hasrw _init => (isa => 'Bool');

hasrw columns => (
  metaclass   => 'Getopt',
  isa => 'ArrayRef[Int]',
  predicate => 'has_columns',
);

# The input CSV processor.
hasrw _input_csv => ();

# The output CSV processor.
hasrw _output_csv => ();

# Text::CSV options, straight from the manpage.
# We override Text::CSV's default here... because it's WRONG.
our @TextCSVOptions = qw(quote_char escape_char sep_char eol always_quote
      binary keep_meta_info allow_loose_quotes allow_loose_escapes
      allow_whitespace verbatim);
hasrw quote_char => (default => '"');
hasrw escape_char => (default => '"');
hasrw sep_char => (default => ',');
hasrw eol => (default => '');
hasrw always_quote => (default => 0);
hasrw binary => (default => 1);
hasrw keep_meta_info => (default => 0);
hasrw allow_loose_quotes => (default => 0);
hasrw allow_loose_escapes => (default => 0);
hasrw allow_whitespace => (default => 0);
hasrw verbatim => (default => 0);

# output CSV processor defaults to whatever the input value is.
# (Thanks, gphat and t0m.)
for my $attr (@TextCSVOptions) {
  hasrw "output_$attr" => (lazy => 1, default => sub { $_[0]->$attr });
}

sub __normalize_column {
  my($in) = @_;
  return ($in <= 0) ? $in : $in - 1;
}

# TODO: You know, I end up with something like this on a lot of projects.
# Why isn't it easier?
sub _setup_fh {
  my($self, $name) = @_;
  my $fh_name = "_${name}_fh";
  return if $self->$fh_name;  # someone had already injected a fh.
  my $dir = $name eq 'input' ? '' : '>';

  my $fh;
  $self->$name('-') if not defined $self->$name;
  if ($self->$name eq '-') {  # use stdio
    open $fh, "$dir-" or die "open: stdio: $!";
  } else {
    open $fh, $dir, $name or die "open: $name: $!";
  }
  $self->$fh_name($fh);
}

sub init {
  my($self) = @_;
  return if $self->_init;
  $self->_init(1);

  # TODO: zero-based field numbers as an option? nah?
  my @columns = (($self->has_columns ? @{$self->columns} : ()), @{$self->extra_argv});
  $self->columns([map { __normalize_column($_) } @columns]) if @columns;

  $self->_input_csv(Text::CSV->new({
      map { $_ => $self->$_ } @TextCSVOptions }));
  $self->_output_csv(Text::CSV->new({
      map { my $o = "output_$_"; $_ => $self->$o } @TextCSVOptions }));

  $self->_setup_fh($_) for qw(input output);
}

sub run {
  my($self) = @_;
  $self->init;

  # L<perlsyn/"modifiers don't take loop labels">
  INPUT: { do {
    my $data;
    while (defined($data = $self->_input_csv->getline($self->_input_fh))) {
      if ($self->has_columns) {
        @$data = @$data[@{ $self->columns }];
      }
      #warn "# @data/@{$self->columns}\n";
      
      if (!$self->_output_csv->print($self->_output_fh, $data)) {
        warn $self->_output_csv->error_diag;
        next INPUT;
      }
      $self->_output_fh->print("\n");
    }

    # keeps us going on input errors.
    # TODO: strict errors, according to command line, blah
    if (not defined $data) {
      last INPUT if $self->_input_csv->eof;
      warn $self->_input_csv->error_diag;
    }
  } }
}

1;
