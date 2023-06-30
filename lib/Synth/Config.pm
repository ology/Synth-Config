package Synth::Config;

# ABSTRACT: Synthesizer settings librarian

our $VERSION = '0.0022';

use Moo;
use strictures 2;
use Carp qw(croak);
use Mojo::JSON qw(from_json to_json);
use Mojo::SQLite ();
use namespace::clean;

=head1 SYNOPSIS

  use Synth::Config ();

  my $model = 'Moog Matriarch';

  my $synth = Synth::Config->new(model => $model);

  my $name = 'Foo!';

  my $id1 = $synth->make_setting(name => $name, etc => '...');
  my $id2 = $synth->make_setting(name => $name, etc => '???');

  my $setting = $synth->recall_setting(id => $id1);
  # { etc => '...' }

  # update the etc key only
  $synth->make_setting(id => $id1, etc => '!!!');

  my $settings = $synth->search_settings(etc => '???');
  # [ 2 => { etc => '???' } ]

  my $models = $synth->recall_models;
  # [ 'moog_matriarch' ]

  my $names = $synth->recall_names;
  # [ 'Foo!' ]

  $synth->remove_setting(id => $id1);

  $synth->remove_settings(name => $name);

  $synth->remove_model(model => $model);

=head1 DESCRIPTION

C<Synth::Config> provides a way to save and recall synthesizer control
settings in a database.

This does B<not> control the synth. It is simply a way to manually
record the parameters defined by knob, slider, switch, or patch
settings in an SQLite database. It is a "librarian", if you will.

=head1 ATTRIBUTES

=head2 model

  $model = $synth->model;

The model name of the synthesizer.

This is turned into lowercase and all non-alpha-num characters are
converted to an underline character (C<_>).

=cut

has model => (
  is => 'rw',
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

has _sqlite => (is => 'lazy');

sub _build__sqlite {
  my ($self) = @_;
  my $sqlite = Mojo::SQLite->new('sqlite:' . $self->dbname);
  return $sqlite->db;
}

=head2 verbose

  $verbose = $synth->verbose;

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
  return unless $args->{model};
  # sanitize the model name
  (my $model = $args->{model}) =~ s/\W/_/g;
  $self->model(lc $model);
  # create the model table unless it's already there
  $self->_sqlite->query(
    'create table if not exists '
    . $self->model
    . ' (
        id integer primary key autoincrement,
        settings json not null,
        name text not null
      )'
  );
}

=head2 make_setting

  my $id = $synth->make_setting(%args);

Save a named setting and return the record id.

The B<name> is required. If an B<id> is given, an update is performed.
Otherwise, a database insert is made.

Example:

  name: 'My Best Setting!'
  settings:
    group   parameter control bottom top   value unit is_default
    filters cutoff    knob    20     20000 200   Hz   true

  name: 'My Other Best Setting!'
  settings:
    group parameter control group_to param_to is_default
    mixer output    patch   filters  vcf-1-in true

=cut

sub make_setting {
  my ($self, %args) = @_;
  my $id = delete $args{id};
  my $name = delete $args{name};
  croak 'No columns given' unless keys %args;
  if ($id) {
    my $result = $self->_sqlite->select(
      $self->model,
      ['settings'],
      { id => $id },
    )->expand(json => 'settings')->hash->{settings};
    for my $arg (keys %args) {
      delete $args{$arg} if $args{$arg} eq '' && !exists $result->{$arg};
    }
    my $params = { %$result, %args };
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
        name     => $name,
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
  my $result = $self->_sqlite->select(
    $self->model,
    ['name', 'settings'],
    { id => $id },
  )->expand(json => 'settings')->hash;
  my $setting = $result->{settings};
  $setting->{name} = $result->{name};
  return $setting;
}

=head2 search_settings

  my $settings = $synth->search_settings(some_setting => $value);

Return all the settings given a search query.

=cut

sub search_settings {
  my ($self, %args) = @_;
  my $name = delete $args{name};
  my @where;
  push @where, "name = '$name'" if $name;
  for my $arg (keys %args) {
    next unless $args{$arg};
    push @where, q/json_extract(settings, '$./ . $arg . q/') = / . "'$args{$arg}'";
  }
  return [] unless @where;
  my $sql = q/select id,name,settings,json_extract(settings, '$.group') as mygroup from /
    . $self->model
    . ' where ' . join(' and ', @where)
    . ' order by mygroup';
  print "SQL: $sql\n" if $self->verbose;
  my $results = $self->_sqlite->query($sql);
  my @settings;
  while (my $next = $results->hash) {
    push @settings, { $next->{id} => from_json($next->{settings}) };
    # add the setting name to the settings data
    $settings[-1]->{ $next->{id} }{name} = $next->{name};
  }
  return \@settings;
}

=head2 recall_all

  my $settings = $synth->recall_all;

Return all the settings for the synth model.

=cut

sub recall_all {
  my ($self) = @_;
  my $sql = q/select id,name,settings,json_extract(settings, '$.group') as mygroup from /
    . $self->model
    . ' order by name,mygroup';
  my $results = $self->_sqlite->query($sql);
  my @settings;
  while (my $next = $results->hash) {
    push @settings, { $next->{id} => from_json($next->{settings}) };
    # add the setting name to the settings data
    $settings[-1]->{ $next->{id} }{name} = $next->{name};
  }
  return \@settings;
}

=head2 recall_models

  my $models = $synth->recall_models;

Return all the models.

=cut

sub recall_models {
  my ($self) = @_;
  my @models;
  my $results = $self->_sqlite->query(
    "select name from sqlite_schema where type='table' order by name"
  );
  while (my $next = $results->array) {
    next if $next->[0] =~ /^sqlite/;
    push @models, $next->[0];
  }
  return \@models;
}

=head2 recall_names

  my $names = $synth->recall_names;

Return all the setting names.

=cut

sub recall_names {
  my ($self) = @_;
  my @names;
  my $results = $self->_sqlite->query(
    'select distinct name from ' . $self->model
  );
  while (my $next = $results->array) {
    push @names, $next->[0];
  }
  return \@names;
}

=head2 remove_setting

  $synth->remove_setting(id => $id);

Remove a setting given an B<id>.

=cut

sub remove_setting {
  my ($self, %args) = @_;
  my $id = delete $args{id};
  croak 'No id given' unless $id;
  $self->_sqlite->delete(
    $self->model,
    { id => $id }
  );
}

=head2 remove_settings

  $synth->remove_settings(name => $name);

Remove all settings for a given B<name>.

=cut

sub remove_settings {
  my ($self, %args) = @_;
  my $name = delete $args{name};
  croak 'No name given' unless $name;
  $self->_sqlite->delete(
    $self->model,
    { name => $name }
  );
}

=head2 remove_model

  $synth->remove_model(model => $model);

Remove the database table for a given B<model>.

=cut

sub remove_model {
  my ($self, %args) = @_;
  my $model = delete $args{model};
  croak 'No model given' unless $model;
  $self->_sqlite->query(
    'drop table ' . $self->model
  );
}

1;
__END__

=head1 SEE ALSO

The F<t/01-methods.t> file in this distribution

L<Moo>

L<Mojo::JSON>

L<Mojo::SQLite>

Knob: L<https://codepen.io/jhnsnc/pen/KXYayG>

Switch: L<https://codepen.io/magnus16/pen/grzqMz>

Slider: L<?>

=cut
