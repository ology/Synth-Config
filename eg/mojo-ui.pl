#!/usr/bin/env perl
use Mojolicious::Lite -signatures;

use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);
use IO::Prompt::Tiny qw(prompt);
use Term::Choose ();
use Mojo::JSON qw(to_json);

use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(Synth-Config);
use Synth::Config ();

get '/' => sub ($c) {
  my $model = $c->param('model');
  my $name = $c->param('name');
  my $group = $c->param('group');
  my ($groups, $settings);
  if ($model) {
    my $synth = Synth::Config->new(model => $model);
    # get a specs config file for the synth model
    my $set = './eg/' . $synth->model . '.set';
    my $specs = -e $set ? do $set : undef;
    # get the known groups if there are specs
    $groups = $specs ? $specs->{group} : undef;
    $groups = [ sort @$groups ] if $groups;
    $settings = $synth->search_settings(group => $group);
  }
  $c->render(
    template => 'index',
    model    => $model,
    name     => $name,
    group    => $group,
    groups   => $groups,
    settings => $settings,
  );
} => 'index';

get '/edit' => sub ($c) {
  my $name       = $c->param('name');
  my $model      = $c->param('model');
  my $group      = $c->param('group');
  my $parameter  = $c->param('parameter');
  my $control    = $c->param('control');
  my $group_to   = $c->param('group_to');
  my $param_to   = $c->param('param_to');
  my $bottom     = $c->param('bottom');
  my $top        = $c->param('top');
  my $value      = $c->param('value');
  my $unit       = $c->param('unit');
  my $is_default = $c->param('is_default');
  my $synth = Synth::Config->new(model => $model);
  # get a specs config file for the synth model
  my $set = './eg/' . $synth->model . '.set';
  my $specs = -e $set ? do $set : undef;
  unless ($specs) {
    $c->flash(error => 'No known model');
    return $c->redirect_to('index');
  }
  $c->render(
    template   => 'edit',
    specs      => $specs,
    name       => $name,
    model      => $model,
    group      => $group,
    parameter  => $parameter,
    control    => $control,
    group_to   => $group_to,
    param_to   => $param_to,
    bottom     => $bottom,
    top        => $top,
    value      => $value,
    unit       => $unit,
    is_default => $is_default,
  );
} => 'edit';

post '/update' => sub ($c) {
  my $v = $c->validation;
  $v->required('name');
  $v->required('model');
  $v->required('group');
  $v->required('parameter');
  $v->required('control');
  $v->optional('group_to');
  $v->optional('param_to');
  $v->optional('bottom');
  $v->optional('top');
  $v->optional('value');
  $v->optional('unit');
  $v->optional('is_default');
  if ($v->failed->@*) {
    $c->flash(error => 'Could not update');
    return $c->redirect_to('edit');
  }
  my $synth = Synth::Config->new(model => $v->param('model'));
  # get a specs config file for the synth model
  my $set = './eg/' . $synth->model . '.set';
  my $specs = -e $set ? do $set : undef;
  my $settings = $synth->search_settings(group => $v->param('group'));
  $c->redirect_to('index');
} => 'update';

helper to_json => sub ($c, $data) {
  return to_json $data;
};

app->start;

__DATA__

@@ index.html.ep
% layout 'default';
% title 'Synth::Config';
<form action="<%= url_for('index') %>" method="get">
  <label for="model">Model:</label>
  <input name="model" id="model" value="<%= $model %>">
  <label for="name">Name:</label>
  <input name="name" id="name" value="<%= $name %>">
  <select name="group" id="group">
% for my $g (@$groups) {
    <option value="">Group...</option>
    <option value="<%= $g %>" <%= $g eq $group ? 'selected' : '' %>><%= ucfirst $g %></option>
% }
  </select>
  <input type="submit" value="Submit">
</form>
<a href="<%= url_for('edit')->query(model => $model, name => $name) %>">Edit</a>
<p></p>
% for my $s (@$settings) {
%   my $setting = (values(%$s))[0];
%   if ($setting->{bottom} && $setting->{top}) {
<b>Param</b>: <i><%= $setting->{parameter} %></i> <%= $setting->{control} %> (<%= $setting->{bottom} %>-<%= $setting->{top} %>),
<b>Value</b>: <%= $setting->{value} %> <%= $setting->{unit} %>,
<b>Default</b>: <%= $setting->{is_default} %>
%   }
<br>
% }

@@ edit.html.ep
% layout 'default';
% title 'Synth::Config Update';
<form action="<%= url_for('index') %>" method="get">
  <label for="model">Model:</label>
  <input name="model" id="model" value="<%= $model %>">
  <label for="name">Name:</label>
  <input name="name" id="name" value="<%= $name %>">
% for my $key ($specs->{order}->@*) {
  <%== $key eq 'value' || $key eq 'parameter' ? '<p></p>' : '' %>
  <select name="<%= $key %>" id="<%= $key %>">
    <option value=""><%= ucfirst $key %>...</option>
%   $key = 'group' if $key eq 'group_to';
%   my @things = $key eq 'parameter' ? () : $specs->{$key}->@*;
%   for my $i (@things) {
    <option value="<%= $i %>"><%= ucfirst $i %></option>
%   }
  </select>
% }
  <p></p>
  <input type="submit" value="Submit">
</form>

<script>
$(document).ready(function() {
  $("select#group").on('change', function() {
    const selected = $("select#group").find(":selected").val();
    const dropdown = $("select#parameter");
    const json = '<%= to_json $specs->{parameter} %>'.replace(/&quot;/g, '"');
    const params = JSON.parse(json);
    const obj = params[selected];
    obj.forEach((i) => {
      dropdown.append($('<option></option>').val(i).text(i));
    });
  });
  $("select#group_to").on('change', function() {
    const selected = $("select#group_to").find(":selected").val();
    const dropdown = $("select#param_to");
    const json = '<%= to_json $specs->{parameter} %>'.replace(/&quot;/g, '"');
    const params = JSON.parse(json);
    const obj = params[selected];
    obj.forEach((i) => {
      dropdown.append($('<option></option>').val(i).text(i));
    });
  });
});
</script>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %></title>
    <script src="https://cdn.jsdelivr.net/npm/jquery@3.7.0/dist/jquery.min.js"></script>
  </head>
  <body><%= content %></body>
</html>
