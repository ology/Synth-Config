package Synth::Config;

# ABSTRACT: Synthesizer settings librarian

our $VERSION = '0.0003';

use Moo;
use strictures 2;
use Carp qw(croak);
use Mojo::JSON qw(to_json);
use Mojo::SQLite ();
use namespace::clean;

=head1 SYNOPSIS

  use Synth::Config ();

  my $synth = Synth::Config->new(model => 'Moog Matriarch');

  my $id = $synth->make_setting(foo => 'bar', etc => '...');

  my $setting = $synth->recall_setting(id => $id);
  # { foo => 'bar', etc => '...' }

  #my $result = $synth->render_setting(...); # TODO

=head1 DESCRIPTION

C<Synth::Config> provides a way to save and recall synthesizer control
settings in a database.

This does B<not> control the synth. It is simply a way to manually
record the parameters defined by knob, slider, switch, or patch
settings in an SQLite database. It is a "librarian", if you will.

=head1 ATTRIBUTES

=head2 model

  $model = $synth->model;

The B<required> model name of the synthesizer.

This is turned into lowercase and all non-alpha-num characters are
converted to an underline character (C<_>).

=cut

has model => (
  is       => 'rw',
  required => 1,
);

=head2 dbname

  $dbname = $synth->dbname;

Database name

Default: C<synth-config.db>

=cut

has dbname => (
  is       => 'ro',
  required => 1,
  default  => sub { 'synth-config.db' },
);

has _sqlite => (
  is => 'lazy',
);

sub _build__sqlite {
  my ($self) = @_;
  my $sqlite = Mojo::SQLite->new('sqlite:' . $self->dbname);
  return $sqlite->db;
}

=head2 verbose

  $verbose = $x->verbose;

Show progress.

=cut

has verbose => (
  is      => 'ro',
  isa     => sub { croak "$_[0] is not a boolean" unless $_[0] =~ /^[01]$/ },
  default => sub { 0 },
);

=head1 METHODS

=head2 new

  $synth = Synth::Config->new(model => $model);

Create a new C<Synth::Config> object.

This automatically makes an SQLite database with a table named for the
given B<model>.

=for Pod::Coverage BUILD

=cut

sub BUILD {
  my ($self, $args) = @_;
  # sanitize the model name
  (my $model = $args->{model}) =~ s/\W/_/g;
  $self->model(lc $model);
  # create the model table unless it's already there
  $self->_sqlite->query(
    'create table if not exists '
    . $self->model
    . ' (id integer primary key autoincrement, settings text not null)'
  );
}

=head2 make_setting

  my $id = $synth->make_setting(%args);

Save a setting with a db "update or insert" operation and return the
record id.

Example:

  group  parameter control bottom top   value unit is_default
  filter cutoff    knob    20     20000 200   Hz   true

=cut

sub make_setting {
  my ($self, %args) = @_;
  my $id = delete $args{id};
  croak 'No columns given' unless keys %args;
  if ($id) {
    my $setting = $self->_sqlite->select(
      $self->model,
      ['settings'],
      { id => $id },
    )->expand(json => 'settings')->hash;
    my $params = { %{ $setting->{settings} }, %args };
    $self->_sqlite->update(
      $self->model,
      { settings => to_json($params) },
      { id => $id },
    );
  }
  else {
    $id = $self->_sqlite->insert(
      $self->model,
      {
        id       => $id,
        settings => to_json(\%args),
      },
    )->last_insert_id;
  }
  return $id;
}

=head2 recall_setting

  my $setting = $synth->recall_setting(id => $id);

Return the parameters of a setting for the given B<id>.

=cut

sub recall_setting {
  my ($self, %args) = @_;
  my $id = delete $args{id};
  croak 'No id given' unless $id;
  my $setting = $self->_sqlite->select(
    $self->model,
    ['settings'],
    {
      id => $id,
    },
  )->expand(json => 'settings')->hash;
  return $setting;
}

1;
__END__

=head1 SEE ALSO

L<Moo>

L<Mojo::JSON>

L<Mojo::SQLite>

Knob: L<https://codepen.io/jhnsnc/pen/KXYayG>

Switch: L<https://codepen.io/magnus16/pen/grzqMz>

Slider: L<?>

=cut
