#!/usr/bin/env perl
use Mojolicious::Lite -signatures;

use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);
use IO::Prompt::Tiny qw(prompt);
use Mojo::JSON qw(to_json);
use Term::Choose ();

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
    if ($group) {
      $settings = $synth->search_settings(group => $group, name => $name);
    }
    elsif ($name) {
      $settings = $synth->search_settings(name => $name);
    }
    elsif ($synth->model) {
      $settings = $synth->recall_all;
    }
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

get '/remove' => sub ($c) {
  my $id    = $c->param('id');
  my $name  = $c->param('name');
  my $model = $c->param('model');
  my $synth = Synth::Config->new(model => $model);
  $synth->remove_setting(id => $id);
  $c->flash(message => 'Delete successful');
  return $c->redirect_to($c->url_for('index')->query(model => $model, name => $name));
} => 'remove';

get '/edit' => sub ($c) {
  my $id         = $c->param('id');
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
  my $selected = {
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
  };
  $c->render(
    template => 'edit',
    specs    => $specs,
    id       => $id,
    name     => $name,
    model    => $model,
    selected => $selected,
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
  $v->optional('id');
  if ($v->failed->@*) {
    $c->flash(error => 'Could not update');
    return $c->redirect_to('edit');
  }
  my $synth = Synth::Config->new(model => $v->param('model'));
  # get a specs config file for the synth model
  my $set = './eg/' . $synth->model . '.set';
  my $specs = -e $set ? do $set : undef;
  my $id = $synth->make_setting(
    id         => $v->param('id'),
    name       => $v->param('name'),
    group      => $v->param('group'),
    parameter  => $v->param('parameter'),
    control    => $v->param('control'),
    group_to   => $v->param('group_to'),
    param_to   => $v->param('param_to'),
    bottom     => $v->param('bottom'),
    top        => $v->param('top'),
    value      => $v->param('value'),
    unit       => $v->param('unit'),
    is_default => $v->param('is_default'),
  );
  $c->flash(message => 'Update successful');
  $c->redirect_to($c->url_for('edit')->query(
    id         => $id,
    name       => $v->param('name'),
    model      => $v->param('model'),
    group      => $v->param('group'),
    parameter  => $v->param('parameter'),
    control    => $v->param('control'),
    group_to   => $v->param('group_to'),
    param_to   => $v->param('param_to'),
    bottom     => $v->param('bottom'),
    top        => $v->param('top'),
    value      => $v->param('value'),
    unit       => $v->param('unit'),
    is_default => $v->param('is_default'),
  ));
} => 'update';

helper to_json => sub ($c, $data) {
  return to_json $data;
};

app->secrets(['yabbadabbadoo']);

app->start;

__DATA__

@@ index.html.ep
% layout 'default';
% title 'Synth::Config';
<p></p>
<form action="<%= url_for('index') %>" method="get">
<div class="row">
  <div class="col">
    <label for="model" class="form-label">Model:</label>
    <input name="model" id="model" value="<%= $model %>" class="form-control">
  </div>
  <div class="col">
    <label for="name" class="form-label">Name:</label>
    <input name="name" id="name" value="<%= $name %>" class="form-control">
  </div>
  <div class="col">
    <label for="group" class="form-label">Group:</label>
    <select name="group" id="group" class="form-select">
      <option value="">Group...</option>
% for my $g (@$groups) {
      <option value="<%= $g %>" <%= $g eq $group ? 'selected' : '' %>><%= ucfirst $g %></option>
% }
    </select>
  </div>
</div>
<p></p>
<div class="row">
  <div class="col">
    <input type="submit" value="Submit" class="btn btn-primary">
    <a href="<%= url_for('edit')->query(model => $model, name => $name, group => $group) %>" class="btn btn-success">New setting</a>
  </div>
</div>
</form>
<p></p>
% for my $s (@$settings) {
%   my $id = (keys(%$s))[0];
%   my $setting = (values(%$s))[0];
%   my $edit_url = url_for('edit')->query(
%     model      => $model,
%     id         => $id,
%     name       => $setting->{name},
%     group      => $setting->{group},
%     parameter  => $setting->{parameter},
%     control    => $setting->{control},
%     group_to   => $setting->{group_to},
%     param_to   => $setting->{param_to},
%     bottom     => $setting->{bottom},
%     top        => $setting->{top},
%     value      => $setting->{value},
%     unit       => $setting->{unit},
%     is_default => $setting->{is_default},
%   );
<a href="<%= $edit_url %>" class="btn btn-sm btn-outline-dark">Edit</a>
<b>Name</b>: <%= $setting->{name} %> ,
<b>Group</b>: <%= $setting->{group} %> ,
<b>Param</b>: <i><%= $setting->{parameter} %></i> <%= $setting->{control} %>
%   if ($setting->{group_to}) {
<b>To</b>: <i><%= $setting->{param_to} %></i> of <%= $setting->{group_to} %>
%   }
%   if ($setting->{value}) {
,
<b>Value</b>: <%= $setting->{value} %> <%= $setting->{unit} %>
%   }
<br>
% }

@@ edit.html.ep
% layout 'default';
% title 'Synth::Config Update';
<p></p>
<form action="<%= url_for('update') %>" method="post">
  <input type="hidden" name="id" value="<%= $id %>">
<div class="row">
  <div class="col-6">
  <label for="model" class="form-label">Model:</label>
  <input type="text" name="model" id="model" value="<%= $model %>">
  </div>
  <div class="col-6">
  <label for="name" class="form-label">Name:</label>
  <input type="text" name="name" id="name" value="<%= $name %>">
  </div>
</div>
<div class="row">
% for my $key ($specs->{order}->@*) {
  <div class="col">
  <%== $key eq 'group' || $key eq 'group_to' || $key eq 'value' || $key eq 'bottom' || $key eq 'is_default' || $key eq 'control' ? '</div></div><div class="row"><div class="col">' : '' %>
    <label for="<%= $key %>" class="form-label"><%= ucfirst $key %>:</label>
%   if ($key eq 'value') {
    <input type="text" name="value" id="value" value="<%= $selected->{value} %>">
%   } elsif ($key eq 'is_default') {
    <div class="form-check form-check-inline">
      <input class="form-check-input" type="radio" name="is_default" id="is_default_false" value="0" <%= $selected->{is_default} ? '' : 'checked' %>>
      <label class="form-check-label" for="is_default_false">False</label>
    </div>
    <div class="form-check form-check-inline">
      <input class="form-check-input" type="radio" name="is_default" id="is_default_true" value="1" <%= $selected->{is_default} ? 'checked' : '' %>>
      <label class="form-check-label" for="is_default_true">True</label>
    </div>
%   } else {
    <select name="<%= $key %>" id="<%= $key %>">
      <option value=""><%= ucfirst $key %>...</option>
%   my $my_key = $key eq 'group_to' ? 'group' : $key;
%   my @things = $key eq 'parameter' ? ($selected->{parameter}) : $key eq 'param_to' ? ($selected->{param_to}) : $specs->{$my_key}->@*;
%     for my $i (@things) {
%       next if !defined($i) || $i eq 'none' || $i eq '';
      <option value="<%= $i %>" <%= $selected->{$key} && $i eq $selected->{$key} ? 'selected' : '' %>><%= ucfirst $i %></option>
%     }
%   }
    </select>
  </div>
% }
</div>
  <p></p>
  <input type="submit" value="Submit" class="btn btn-primary">
  <a href="<%= url_for('remove')->query(id => $id, model => $model, name => $name) %>" class="btn btn-danger" onclick="if(!confirm('Remove setting <%= $id %>?')) return false;">Remove</a>
  <a href="<%= url_for('index')->query(model => $model, name => $name) %>" class="btn btn-warning">Cancel</a>
</form>

<script>
$(document).ready(function() {
  function populate (group, param) {
    const selected = $("select#" + group).find(":selected").val();
    const dropdown = $("select#" + param);
    const json = '<%= to_json $specs->{parameter} %>'.replace(/&quot;/g, '"');
    const params = JSON.parse(json);
    const obj = params[selected];
    dropdown.empty();
    dropdown.append($('<option></option>').val("").text('Select...'));
    obj.forEach((i) => {
      let text = i.replace(/-/g, ' ');
      text = text.charAt(0).toUpperCase() + text.substring(1);
      dropdown.append($('<option></option>').val(i).text(text));
    });
  }
  $("select#group").on('change', function() {
    populate("group", "parameter");
  });
  $("select#group_to").on('change', function() {
    populate("group_to", "param_to");
  });
});
</script>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html lang="en">
  <head>
    <title><%= title %></title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-EVSTQN3/azprG1Anm3QDgpJLIm9Nao0Yz1ztcQTwFspd3yD65VohhpuuCOmLASjC" crossorigin="anonymous">
    <script src="https://cdn.jsdelivr.net/npm/jquery@3.7.0/dist/jquery.min.js"></script>
  </head>
  <body>
    <div class="container">
% if (flash('error')) {
    %= tag h3 => (style => 'color:red') => flash('error')
% }
% if (flash('message')) {
    %= tag h3 => (style => 'color:green') => flash('message')
% }
    <%= content %>
    </div>
  </body>
</html>
