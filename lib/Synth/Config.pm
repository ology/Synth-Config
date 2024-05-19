package Synth::Config;

# ABSTRACT: Synthesizer settings librarian

our $VERSION = '0.0048';

use Moo;
use strictures 2;
use Carp qw(croak);
use GraphViz2 ();
use Mojo::JSON qw(from_json to_json);
use Mojo::SQLite ();
use YAML qw(Load LoadFile);
use namespace::clean;

=head1 SYNOPSIS

  use Synth::Config ();

  my $model = 'Moog Matriarch';

  my $synth = Synth::Config->new(model => $model);

  my $patch = 'My favorite setting';

  my $id1 = $synth->make_setting(name => $patch, group => 'filter', etc => '...');
  my $id2 = $synth->make_setting(name => $patch, group => 'sequencer', etc => '...');

  my $setting = $synth->recall_setting(id => $id1);
  # { id => 1, group => 'filter' }

  # update the group key
  $synth->make_setting(id => $id1, group => 'envelope');

  my $settings = $synth->search_settings(name => $patch);
  # [ { id => 1, group => 'envelope', etc => '...' }, { id => 2, group => 'sequencer', etc => '...' } ]

  $settings = $synth->search_settings(group => 'sequencer');
  # [ { id => 2, group => 'sequencer', etc => '...' } ]

  $g = $synth->graphviz(
    settings   => $settings,
    model_name => $model,
    patch_name => $patch,
    render     => 1,
  );

  my $models = $synth->recall_models;
  # [ 'moog_matriarch' ]

  my $names = $synth->recall_names;
  # [ 'My favorite setting' ]

  # declare the possible settings
  my %spec = (
    order      => [qw(group parameter control group_to param_to bottom top value unit is_default)],
    group      => [],
    parameter  => {},
    control    => [qw(knob switch slider patch)],
    group_to   => [],
    param_to   => [],
    bottom     => [qw(off 0 1 7AM 20)],
    top        => [qw(on 3 4 6 7 5PM 20_000 100%)],
    value      => [],
    unit       => [qw(Hz o'clock)],
    is_default => [0, 1],
  );
  my $spec_id = $synth->make_spec(%spec);
  my $spec = $synth->recall_spec(id => $spec_id);
  my $specs = $synth->recall_specs;
  # [ { order => [ ... ], etc => ... } ]

  # remove stuff!
  $synth->remove_spec;
  $synth->remove_setting(id => $id1);      # remove a particular setting
  $synth->remove_settings(name => $patch); # remove all settings sharing the same name
  $synth->remove_model(model => $model);   # remove the entire model

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
  # create the model specs table unless it's already there
  $self->_sqlite->query(
    'create table if not exists specs'
    . ' (
        id integer primary key autoincrement,
        model text not null,
        spec json not null
      )'
  );
}

=head2 make_setting

  my $id = $synth->make_setting(%args);

Save a named setting and return the record id.

The B<name> is required to perform an insert. If an B<id> is given, an
update is performed.

The setting is a single JSON field that can contain any key/value
pairs. These pairs B<must> include at least a C<group> to be
searchable.

Example:

  name: 'My Best Setting!'
  settings:
    group   parameter control bottom top   value unit is_default
    filters cutoff    knob    20     20000 200   Hz   1

  name: 'My Other Best Setting!'
  settings:
    group parameter control group_to param_to is_default
    mixer output    patch   filters  vcf-1-in 0

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
      $args{$arg} = '' unless defined $args{$arg};
    }
    my $params = { %$result, %args };
    $self->_sqlite->update(
      $self->model,
      { settings => to_json($params) },
      { id => $id },
    );
  }
  elsif ($name) {
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
  $setting->{id} = $id;
  $setting->{name} = $result->{name};
  return $setting;
}

=head2 search_settings

  my $settings = $synth->search_settings(
    some_setting    => $valu2,
    another_setting => $value2,
  );

Return all the settings given a search query.

=cut

sub search_settings {
  my ($self, %args) = @_;
  my $name = delete $args{name};
  my @where;
  push @where, "name = '$name'" if $name;
  for my $arg (keys %args) {
    next unless $args{$arg};
    $args{$arg} =~ s/'/''/g; # escape the single-quote
    push @where, q/json_extract(settings, '$./ . $arg . q/') = / . "'$args{$arg}'";
  }
  return [] unless @where;
  my $sql = q/select id,name,settings,json_extract(settings, '$.group') as mygroup, json_extract(settings, '$.parameter') as parameter from /
    . $self->model
    . ' where ' . join(' and ', @where)
    . ' order by name,mygroup,parameter';
  print "Search SQL: $sql\n" if $self->verbose;
  my $results = $self->_sqlite->query($sql);
  my @settings;
  while (my $next = $results->hash) {
    my $set = from_json($next->{settings});
    $set->{id} = $next->{id};
    $set->{name} = $next->{name};
    push @settings, $set;
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
    my $set = from_json($next->{settings});
    $set->{id} = $next->{id};
    $set->{name} = $next->{name};
    push @settings, $set;
  }
  return \@settings;
}

=head2 recall_models

  my $models = $synth->recall_models;

Return all the know models. This method can be called without having
specified a synth B<model> in the constructor.

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

  $synth->remove_model;

Remove the database table for the current object model.

=cut

sub remove_model {
  my ($self) = @_;
  $self->_sqlite->query(
    'drop table ' . $self->model
  );
}

=head2 make_spec

  my $id = $synth->make_spec(%args);

Save a model specification and return the record id.

If an B<id> is given, an update is performed.

The spec is a single JSON field that can contain any key/value
pairs that define the configuration - groups, parameters, values, etc.
of a model.

=cut

sub make_spec {
  my ($self, %args) = @_;
  my $id = delete $args{id};
  croak 'No columns given' unless keys %args;
  if ($id) {
    my $result = $self->_sqlite->select(
      'specs',
      ['spec'],
      { id => $id },
    )->expand(json => 'spec')->hash->{spec};
    for my $arg (keys %args) {
      $args{$arg} = '' unless defined $args{$arg};
    }
    my $params = { %$result, %args };
    $self->_sqlite->update(
      'specs',
      { spec => to_json($params) },
      { id => $id },
    );
  }
  else {
    $id = $self->_sqlite->insert(
      'specs',
      {
        model => $self->model,
        spec  => to_json(\%args),
      },
    )->last_insert_id;
  }
  return $id;
}

=head2 recall_specs

  my $specs = $synth->recall_specs;

Return the specs for the model.

=cut

sub recall_specs {
  my ($self) = @_;
  my $sql = q/select id,model,spec,json_extract(spec, '$.group') as mygroup from /
    . 'specs'
    . " where model = '" . $self->model . "'"
    . ' order by model,mygroup';
  my $results = $self->_sqlite->query($sql);
  my @specs;
  while (my $next = $results->hash) {
    my $set = from_json($next->{spec});
    $set->{id} = $next->{id};
    $set->{model} = $next->{model};
    push @specs, $set;
  }
  return \@specs;
}

=head2 recall_spec

  my $spec = $synth->recall_spec(id => $id);

Return the model configuration specification for the given B<id>.

=cut

sub recall_spec {
  my ($self, %args) = @_;
  my $id = delete $args{id};
  croak 'No id given' unless $id;
  my $result = $self->_sqlite->select(
    'specs',
    ['spec'],
    { id => $id },
  )->expand(json => 'spec')->hash;
  my $spec = $result->{spec};
  $spec->{id} = $id;
  return $spec;
}

=head2 remove_spec

  $synth->remove_spec;

Remove the database table for the current object model configuration
specification.

=cut

sub remove_spec {
  my ($self) = @_;
  $self->_sqlite->delete(
    'specs',
    { model => $self->model }
  );
}

=head1 import_yaml

Add the settings in a L<YAML> file or string, to the database and
return the setting (patch) name.

Import a specific set of B<patches> in the settings, by providing them
in the B<options>.

Option defaults:

  file    = undef
  string  = undef
  patches = undef

=cut

sub import_yaml {
  my ($self, %options) = @_;

  die 'Invalid settings file'
    if $options{file} && !-e $options{file};

  my $config = $options{file}
    ? LoadFile($options{file})
    : Load($options{string});

  my $list = $options{patches}
    ? $options{patches}
    : [ map { $_->{patch} } @{ $config->{patches} } ];

  for my $patch (@$list) {
    my $settings = $self->search_settings(name => $patch);

    if ($settings && @$settings) {
      print "Removing $patch setting from ", $self->model, "\n";
      $self->remove_settings(name => $patch);
    }

    for my $setting (@{ $config->{patches}{$patch}{settings} }) {
      print "Adding $patch setting to ", $self->model, "\n";
      $self->make_setting(name => $patch, %$setting);
    }
  }

  return $list;
}

=head2 graphviz

  $g = $synth->graphviz(%options);

Visualize a patch of B<settings> with the L<GraphViz2> module.

Option defaults:

  render     = 0
  path       = .
  model_name = model
  patch_name = patch
  extension  = png
  shape      = oval
  color      = grey

=cut

sub graphviz {
  my ($self, %options) = @_;

  $options{render}     ||= 0;
  $options{path}       ||= '.';
  $options{model_name} ||= 'model';
  $options{patch_name} ||= 'patch';
  $options{extension}  ||= 'png';
  $options{shape}      ||= 'oval';
  $options{color}      ||= 'grey';

  my $g = GraphViz2->new(
    global => { directed => 1 },
    node   => { shape => $options{shape} },
    edge   => { color => $options{color} },
  );
  my (%edges, %sets, %labels);

  # collect settings by group
  for my $set (@{ $options{settings} }) {
    my $from = $set->{group};
    push @{ $sets{$from} }, $set;
  }

  # accumulate parameter = value lines
  for my $from (keys %sets) {
    my @label = ($from);
    for my $group ($sets{$from}->@*) {
      next if $group->{control} eq 'patch';
      my $label = "$group->{parameter} = $group->{value}$group->{unit}";
      push @label, $label;
    }
    $labels{$from} = join "\n", @label;
  }

  # add patch edges
  for my $s (@{ $options{settings} }) {
    next if $s->{control} ne 'patch';
    my ($from, $to, $param, $param_to) = @$s{qw(group group_to parameter param_to)};
    my $key = "$from $param to $to $param_to";
    my $label = "$param to $param_to";
    $from = $labels{$from};
    $to = $labels{$to} if exists $labels{$to};
    $g->add_edge(
      from  => $from,
      to    => $to,
      label => $label,
    ) unless $edges{$key}++;
  }

  if ($options{render}) {
    # save the file
    (my $model = $options{model_name}) =~ s/\W/_/g;
    (my $patch = $options{patch_name}) =~ s/\W/_/g;
    my $filename = "$options{path}/$model-$patch.$options{extension}";
    $g->run(format => $options{extension}, output_file => $filename);
  }

  return $g;
}

1;
__END__

=head1 SEE ALSO

The F<t/01-methods.t> and the F<eg/*.pl> files in this distribution

L<GraphViz2>

L<Moo>

L<Mojo::JSON>

L<Mojo::SQLite>

=cut
