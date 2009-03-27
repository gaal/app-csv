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

# Why isn't this in Moose?
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
our %TextCSVOptions = (
    quote_char          => ['Str', '"'],
    escape_char         => ['Str', '"'],
    sep_char            => ['Str', ','],
    eol                 => ['Any', undef],
    always_quote        => ['Int', 0],
    binary              => ['Int', 1],
    keep_meta_info      => ['Int', 0],
    allow_loose_quotes  => ['Int', 0],
    allow_loose_escapes => ['Int', 0],
    allow_whitespace    => ['Int', 0],
    verbatim            => ['Int', 0],
);

# output CSV processor options default to whatever the input option is.
# But you can override it just for output by saying --output_foo instead
# of --foo.   (Thanks, gphat and t0m.)
while (my($attr, $opts) = each %TextCSVOptions) {
  my($type, $default) = @$opts;
  hasrw $attr => (isa => $type, default => $default);
  hasrw "output_$attr" => (isa => $type,
      lazy => 1, default => sub { $_[0]->$attr });
}

# TODO: command line aliases?
hasrw from_tsv => (isa => 'Bool', predicate => 'has_from_tsv');
hasrw to_tsv => (isa => 'Bool', predicate => 'has_to_tsv');


sub __normalize_column {
  my($in) = @_;
  return ($in <= 0) ? $in : $in - 1;
}

# TODO: You know, I end up with something like this on a lot of projects.
# Why isn't this easier? Having to remember to "use IO::Handle" is sad, too.
sub _setup_fh {
  my($self, $name) = @_;
  my $fh_name = "_${name}_fh";
  return if $self->$fh_name;  # someone had already injected a fh.

  # ARGH. You can't open $fh, ">-", but you can't open $fh, "", "-" !?
  my $dir2 = $name eq 'input' ? '' : '>';
  my $dir3 = $name eq 'input' ? '<' : '>';

  my $fh;
  $self->$name('-') if not defined $self->$name;
  if ($self->$name eq '-') {  # use stdio
    open $fh, "$dir2-" or die "open: stdio: $!";
  } else {
    open $fh, $dir3, $self->$name or die "open: $self->$name: $!";
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

  $self->_setup_fh($_) for qw(input output);

  # DWIMmy TSV
  if ($self->from_tsv ||
      (!$self->has_from_tsv && $self->input && $self->input =~ /\.tsv$/)) {
    $self->sep_char("\t");
  }
  if ($self->to_tsv ||
      (!$self->has_to_tsv && $self->output && $self->output =~ /\.tsv$/)) {
    $self->output_sep_char("\t");
  }

  $self->_input_csv(Text::CSV->new({
      map { $_ => $self->$_ } keys %TextCSVOptions }));
  $self->_output_csv(Text::CSV->new({
      map { my $o = "output_$_"; $_ => $self->$o } keys %TextCSVOptions }));
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
__END__
=head1 NAME

App::CSV - process CSV files

=head1 REDIRECTION

Please see L<csv>.

=cut
