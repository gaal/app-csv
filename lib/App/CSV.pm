package App::CSV;

use Moose;
use Text::CSV;

our $VERSION = '0.01';

with 'MooseX::Getopt';

has _input_fh => (
  # isa => 'FileHandle' (or IO::String...)
  is => 'rw',
);

has _output_fh => (
  # isa => 'FileHandle' (or IO::String...)
  is => 'rw',
);

has _init => (
  isa => 'Bool',
  is => 'rw',
);

has columns => (
  metaclass   => 'Getopt',
  isa => 'ArrayRef[Int]',
  is => 'rw',
  predicate => 'has_columns',
);

# The input CSV processor.
has _input_csv => (
  is => 'rw',
);

# The output CSV processor.
has _output_csv => (
  is => 'rw',
);


sub __normalize_column {
  my($in) = @_;
  return ($in <= 0) ? $in : $in - 1;
}

sub init {
  my($self) = @_;
  return if $self->_init;
  $self->_init(1);

  # TODO: zero-based field numbers as an option? nah?
  my @columns = (($self->has_columns ? @{$self->columns} : ()), @{$self->extra_argv});
  $self->columns([map { __normalize_column($_) } @columns]) if @columns;

  # TODO: use parameters for binary, quote strictness, blah blah.
  $self->_input_csv(Text::CSV->new);
  $self->_output_csv(Text::CSV->new);
}

sub run {
  my($self) = @_;
  $self->init;

  INPUT: while (defined(my $line = readline $self->_input_fh)) {
    # TODO: strict errors, according to command line, blah
    if (!$self->_input_csv->parse($line)) {
      warn $self->_input_csv->error_diag;
      next INPUT;
    }

    my @data = $self->_input_csv->fields;
    if ($self->has_columns) {
      @data = @data[@{ $self->columns }];
    }
    #warn "# @data/@{$self->columns}\n";
    
    if (!$self->_output_csv->combine(@data)) {
      warn $self->_output_csv->error_diag;
      next INPUT;
    }

    my $output = $self->_output_csv->string;
    #warn "# $output\n";
    # TODO: newlines
    $self->_output_fh->print($output, "\n");
  }
}

1;
