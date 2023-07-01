#!/usr/bin/env perl
use Mojolicious::Lite -signatures;

use Data::Dumper::Compact qw(ddc);
use Mojo::JSON qw(to_json);
use Mojo::File ();
use Mojo::Util qw(trim);
use Storable qw(store retrieve);

use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(Synth-Config);
use Synth::Config ();

use constant SETTINGS => './eg/public/settings/';

get '/' => sub ($c) {
  my $model  = $c->param('model');
  my $name   = $c->param('name');
  my $group  = $c->param('group');
  my $fields = $c->param('fields');
  my ($models, $names, $groups, $settings);
  $model  = trim($model)  if $model;
  $name   = trim($name)   if $name;
  $fields = trim($fields) if $fields;
  my $synth = Synth::Config->new(model => $model, verbose => 1);
  if ($model) {
    # get a specs config file for the synth model
    my $set_file = SETTINGS . $synth->model . '.dat';
    my $specs = -e $set_file ? retrieve($set_file) : undef;
    # get the known groups if there are specs
    $groups = $specs ? $specs->{group} : undef;
    $groups = [ sort @$groups ] if $groups;
    # fetch the things!
    if ($group || $name || $fields) {
      my %parameters;
      $parameters{group} = $group if $group;
      $parameters{name}  = $name  if $name;
      if ($fields) {
        my @fields = split /\s*,\s*/, $fields;
        for my $f (@fields) {
          my ($key, $val) = split /\s*:\s*/, $f;
          $parameters{$key} = $val;
        }
      }
      $settings = $synth->search_settings(%parameters);
    }
    elsif ($synth->model) {
      $settings = $synth->recall_all;
    }
    $names = $synth->recall_names;
  }
  $models = $synth->recall_models;
  for my $m (@$models) {
    $m =~ s/_/ /g;
  }
  $c->render(
    template => 'index',
    model    => $model,
    models   => $models,
    name     => $name,
    names    => $names,
    group    => $group,
    groups   => $groups,
    fields   => $fields,
    settings => $settings,
  );
} => 'index';

get '/model' => sub ($c) {
  my $model  = $c->param('model');
  my $specs  = $c->param('specs');
  my $groups = $c->param('groups');
  my $group_list = $groups ? [ split /\s*,\s*/, $groups ] : undef;
  $c->render(
    template   => 'model',
    model      => $model,
    specs      => $specs,
    groups     => $groups,
    group_list => $group_list,
  );
} => 'model';
post '/model' => sub ($c) {
  my $v = $c->validation;
  $v->required('model');
  $v->required('groups');
  if ($v->failed->@*) {
    $c->flash(error => 'Could not update model');
    return $c->redirect_to('model');
  }
  my $synth = Synth::Config->new(model => $v->param('model'));
  my $group_params = $c->every_param('group');
  if (@$group_params) {
    my $model_file = SETTINGS . $synth->model . '.dat';
    my @groups = split /\s*,\s*/, $v->param('groups');
    my $specs = -e $model_file ? retrieve($model_file) : undef;
    my $i = 0;
    for my $g (@groups) {
      $specs->{parameter}{$g} = [ split /\s*,\s*/, $group_params->[$i] ];
      $i++;
    }
    store($specs, $model_file);
    $c->flash(message => 'Update parameters successful');
    return $c->redirect_to($c->url_for('index')->query(model => $v->param('model')));
  }
  else {
    my $init_file = Mojo::File->new(SETTINGS . 'initial.set');
    my $specs = -e $init_file ? do $init_file : undef;
    unless ($specs) {
      $c->flash(error => 'Invalid init file');
      return $c->redirect_to('model');
    }
    $specs->{group} = [ split /\s*,\s*/, $v->param('groups') ];
    $specs->{parameter}{$_} = [] for $specs->{group}->@*;
    my $model_file = SETTINGS . $synth->model . '.dat';
    store($specs, $model_file);
    $c->flash(message => 'Add model successful');
    return $c->redirect_to($c->url_for('model')->query(model => $v->param('model'), groups => $v->param('groups')));
  }
} => 'update_model';
get '/edit_model' => sub ($c) {
  my $v = $c->validation;
  $v->required('model');
  if ($v->failed->@*) {
    $c->flash(error => 'Could not edit model');
    return $c->redirect_to($c->url_for('index')->query(model => $v->param('model')));
  }
  my $synth = Synth::Config->new(model => $v->param('model'));
  my $model_file = SETTINGS . $synth->model . '.dat';
  my $specs = -e $model_file ? retrieve($model_file) : undef;
  my $groups = join ',', $specs->{group}->@*;
  $c->render(
    template   => 'edit_model',
    model      => $v->param('model'),
    groups     => $groups,
    group_list => $specs->{group},
    specs      => $specs->{parameter},
  );
} => 'edit_model';

get '/remove' => sub ($c) {
  my $v = $c->validation;
  $v->optional('id');
  $v->optional('name');
  $v->optional('model');
  if ($v->failed->@*) {
    $c->flash(error => 'Remove failed');
    return $c->redirect_to('index');
  }
  my $synth = Synth::Config->new(model => $v->param('model'));
  if ($v->param('id')) {
    $synth->remove_setting(id => $v->param('id'));
    $c->flash(message => 'Remove successful');
    return $c->redirect_to($c->url_for('index')->query(model => $v->param('model'), name => $v->param('name')));
  }
  elsif ($synth->model) {
    $synth->remove_model;
    my $model_file = Mojo::File->new(SETTINGS . $synth->model . '.dat');
    $model_file->remove;
    $c->flash(message => 'Remove successful');
    return $c->redirect_to('index');
  }
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
  $model = trim($model) if $model;
  $name  = trim($name)  if $name;
  my $synth = Synth::Config->new(model => $model);
  # get a specs config file for the synth model
  my $set_file = SETTINGS . $synth->model . '.dat';
  my $specs = -e $set_file ? retrieve($set_file) : undef;
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
  my $model = trim $v->param('model') if $v->param('model');
  my $name  = trim $v->param('name')  if $v->param('name');
  my $value = trim $v->param('value') if defined $v->param('value');
  my $synth = Synth::Config->new(model => $model);
  # get a specs config file for the synth model
  my $set_file = SETTINGS . $synth->model . '.dat';
  my $specs = -e $set_file ? retrieve($set_file) : undef;
  my $id = $synth->make_setting(
    id         => $v->param('id'),
    name       => $name,
    group      => $v->param('group'),
    parameter  => $v->param('parameter'),
    control    => $v->param('control'),
    group_to   => $v->param('group_to'),
    param_to   => $v->param('param_to'),
    bottom     => $v->param('bottom'),
    top        => $v->param('top'),
    value      => $value,
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
<p></p>
<form action="<%= url_for('index') %>" method="get">
<div class="row">
  <div class="col">
    <select name="model" id="model" class="form-select" required>
      <option value="">Model name...</option>
% for my $m (@$models) {
      <option value="<%= $m %>" <%= $models && $model && lc($m) eq lc($model) ? 'selected' : '' %>><%= ucfirst $m %></option>
% }
    </select>
  </div>
  <div class="col">
    <select name="name" id="name" class="form-select">
      <option value="">Setting name...</option>
% for my $n (@$names) {
      <option value="<%= $n %>" <%= $names && $n eq $name ? 'selected' : '' %>><%= ucfirst $n %></option>
% }
    </select>
  </div>
  <div class="col">
    <select name="group" id="group" class="form-select">
      <option value="">Group...</option>
% for my $g (@$groups) {
      <option value="<%= $g %>" <%= $group && $g eq $group ? 'selected' : '' %>><%= ucfirst $g %></option>
% }
    </select>
  </div>
</div>
<p></p>
<div class="row">
  <div class="col">
    <input type="text" name="fields" id="fields" value="<%= $fields %>" class="form-control" placeholder="Search field1:value1, field2:value2, etc.">
  </div>
</div>
<p></p>
<div class="row">
  <div class="col">
    <button type="submit" class="btn btn-primary"><i class="fa-solid fa-magnifying-glass"></i> Search</button>
% if ($model) {
    <a href="<%= url_for('edit')->query(model => $model, name => $name, group => $group) %>" class="btn btn-success"><i class="fa-solid fa-plus"></i> New setting</a>
% }
    <a href="<%= url_for('model') %>" class="btn btn-success"><i class="fa-solid fa-database"></i> New model</a>
% if ($model) {
    <a href="<%= url_for('edit_model')->query(model => $model) %>" class="btn btn-success"><i class="fa-solid fa-pencil"></i> Edit model</a>
    <a href="<%= url_for('remove')->query(model => $model) %>" class="btn btn-danger" onclick="if(!confirm('Remove model?')) return false;"><i class="fa-solid fa-trash-can"></i> Remove model</a>
% }
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
<a href="<%= $edit_url %>" class="btn btn-sm btn-outline-secondary"><i class="fa-solid fa-pencil"></i></a>
&nbsp;
<b>Name</b>: <%= $setting->{name} %> ,
<b>Group</b>: <%= $setting->{group} %> ,
<b>Param</b>: <%= $setting->{parameter} %> <b>Control</b>: <i><%= $setting->{control} %></i>
%   if ($setting->{group_to}) {
<b>To</b>: <%= $setting->{param_to} %> of the <%= $setting->{group_to} %> group
%   }
%   if ($setting->{value}) {
,
<b>Value</b>: <%= $setting->{value} %> <%= $setting->{unit} %>
%   }
<br>
% }


@@ model.html.ep
% layout 'default';
<p></p>
<form action="<%= url_for('update_model') %>" method="post">
<div class="row">
  <div class="col">
    <input type="text" name="model" id="model" value="<%= $model %>" class="form-control" placeholder="Model name" required>
  </div>
</div>
<p></p>
<div class="row">
  <div class="col">
    <input type="text" name="groups" id="groups" value="<%= $groups %>" class="form-control" placeholder="group1, group2, etc." required>
  </div>
</div>
<p></p>
<div class="row">
  <div class="col">
% unless ($group_list) {
    <button type="submit" class="btn btn-primary"><i class="fa-solid fa-plus"></i> Add model</button>
% }
    <a href="<%= url_for('index') %>" class="btn btn-warning"><i class="fa-solid fa-xmark"></i> Cancel</a>
  </div>
</div>
</form>
% if ($group_list) {
<p></p>
<form action="<%= url_for('update_model') %>" method="post">
  <input type="hidden" name="model" value="<%= $model %>">
  <input type="hidden" name="groups" value="<%= $groups %>">
%   for my $g (@$group_list) {
  <input type="text" name="group" id="<%= $g %>" class="form-control" placeholder="<%= $g %> parameter1, param2, etc.">
  <p></p>
%   }
  <button type="submit" class="btn btn-primary"><i class="fa-solid fa-plus"></i> Add parameters</button>
</form>
% }


@@ edit_model.html.ep
% layout 'default';
<p></p>
<div class="row">
  <div class="col">
    <label for="model">Model:</label>
    <input type="text" name="model" id="model" value="<%= $model %>" class="form-control" disabled readonly>
  </div>
</div>
<p></p>
<div class="row">
  <div class="col">
    <label for="group">Group:</label>
    <input type="text" id="group" value="<%= $groups %>" class="form-control" disabled readonly>
  </div>
</div>
<p></p>
<form action="<%= url_for('update_model') %>" method="post">
  <input type="hidden" name="model" value="<%= $model %>">
  <input type="hidden" name="groups" value="<%= $groups %>">
% for my $g (@$group_list) {
  <label for="<%= $g %>_param"><%= $g %>:</label>
  <input type="text" name="group" id="<%= $g %>_param" value="<%= join ',', $specs->{$g}->@* %>" class="form-control" placeholder="<%= ucfirst $g %> parameter1, param2, etc.">
  <p></p>
% }
  <div class="row">
    <div class="col">
      <button type="submit" class="btn btn-primary"><i class="fa-solid fa-plus"></i> Update model</button>
      <a href="<%= url_for('index')->query(model => $model) %>" class="btn btn-warning"><i class="fa-solid fa-xmark"></i> Cancel</a>
    </div>
  </div>
</form>


@@ edit.html.ep
% layout 'default';
<p></p>
<form action="<%= url_for('update') %>" method="post">
  <input type="hidden" name="id" value="<%= $id %>">
<div class="row">
  <div class="col">
    <input type="text" name="model" id="model" value="<%= ucfirst $model %>" class="form-control" placeholder="Model name" required>
  </div>
  <div class="col">
    <input type="text" name="name" id="name" value="<%= $name %>" class="form-control" placeholder="Setting name" required>
  </div>
</div>
<p></p>
<div class="row">
  <div class="col">
% my $j = 0;
% for my $key ($specs->{order}->@*) {
%   $j++;
%   if ($j != 1) {
%     unless ($key eq 'parameter' || $key eq 'param_to' || $key eq 'top' || $key eq 'unit') {
<div class="row">
%     }
  <div class="col">
%   }
%   if ($key eq 'value') {
    <input type="text" name="<%= $key %>" id="<%= $key %>" value="<%= $selected->{value} %>" class="form-control" placeholder="Setting value">
%   } elsif ($key eq 'is_default') {
    Is default: &nbsp;
    <div class="form-check form-check-inline">
      <input class="form-check-input" type="radio" name="<%= $key %>" id="is_default_true" value="1" <%= $selected->{is_default} ? 'checked' : '' %>>
      <label class="form-check-label" for="is_default_true">True</label>
    </div>
    <div class="form-check form-check-inline">
      <input class="form-check-input" type="radio" name="<%= $key %>" id="is_default_false" value="0" <%= $selected->{is_default} ? '' : 'checked' %>>
      <label class="form-check-label" for="is_default_false">False</label>
    </div>
%   } else {
    <select name="<%= $key %>" id="<%= $key %>" class="form-select">
      <option value=""><%= ucfirst $key %>...</option>
%   my $my_key = $key eq 'group_to' ? 'group' : $key;
%   my @things = $key eq 'parameter' ? ($selected->{parameter}) : $key eq 'param_to' ? ($selected->{param_to}) : $specs->{$my_key}->@*;
%     for my $i (@things) {
%       next if !defined($i) || $i eq 'none' || $i eq '';
      <option value="<%= $i %>" <%= defined $selected->{$key} && $i eq $selected->{$key} ? 'selected' : '' %>><%= ucfirst $i %></option>
%     }
    </select>
%   }
%   if ($j != $specs->{order}->@*) {
  </div>
%     unless ($key eq 'group' || $key eq 'group_to' || $key eq 'bottom' || $key eq 'value') {
</div>
<p id="<%= $key . '_p' %>"></p>
%     }
%   }
% }
  </div>
</div>
  <p></p>
  <button type="submit" class="btn btn-primary"><i class="fa-solid fa-plus"></i> Submit</button>
% if ($id) {
  <a href="<%= url_for('remove')->query(id => $id, model => $model, name => $name) %>" class="btn btn-danger" onclick="if(!confirm('Remove setting <%= $id %>?')) return false;"><i class="fa-solid fa-trash-can"></i> Remove</a>
% }
  <a href="<%= url_for('index')->query(model => $model, name => $name, group => $selected->{group}) %>" class="btn btn-warning"><i class="fa-solid fa-xmark"></i> Cancel</a>
</form>
<script>
$(document).ready(function() {
  function populate (group, param) {
    const paramUcfirst = param.charAt(0).toUpperCase() + param.substring(1) + '...';
    const selected = $("select#" + group).find(":selected").val();
    const dropdown = $("select#" + param);
    const json = '<%= to_json $specs->{parameter} %>'.replace(/&quot;/g, '"');
    const params = JSON.parse(json);
    const obj = params[selected];
    dropdown.empty();
    dropdown.append($('<option></option>').val("").text(paramUcfirst));
    obj.forEach((i) => {
      let text = i.replace(/-/g, ' ');
      text = text.charAt(0).toUpperCase() + text.substring(1);
      dropdown.append($('<option></option>').val(i).text(text));
    });
  }
  function toggle_patch (selected) {
    if (selected === 'patch') {
      $('label[for="group_to"]').show();
      $("#group_to").show();
      $("#group_to_p").show();
      $('label[for="param_to"]').show();
      $("#param_to").show();
      $("#param_to_p").show();
      $("#bottom").val($("#bottom option:first").val());
      $('label[for="bottom"]').hide();
      $("#bottom").hide();
      $("#bottom_p").hide();
      $("#top").val($("#top option:first").val());
      $('label[for="top"]').hide();
      $("#top").hide();
      $("#top_p").hide();
      $("#value").val('');
      $('label[for="value"]').hide();
      $("#value").hide();
      $("#value_p").hide();
      $("#unit").val($("#unit option:first").val());
      $('label[for="unit"]').hide();
      $("#unit").hide();
      $("#unit_p").hide();
    }
    else {
      $("#group_to").val($("#group_to option:first").val());
      $('label[for="group_to"]').hide();
      $("#group_to").hide();
      $("#group_to_p").hide();
      $("#param_to").val($("#param_to option:first").val());
      $('label[for="param_to"]').hide();
      $("#param_to").hide();
      $("#param_to_p").hide();
      $('label[for="bottom"]').show();
      $("#bottom").show();
      $("#bottom_p").show();
      $('label[for="top"]').show();
      $("#top").show();
      $("#top_p").show();
      $('label[for="value"]').show();
      $("#value").show();
      $("#value_p").show();
      $('label[for="unit"]').show();
      $("#unit").show();
      $("#unit_p").show();
    }
  }
  $("select#group").on('change', function() {
    populate("group", "parameter");
  });
  $("select#group_to").on('change', function() {
    populate("group_to", "param_to");
  });
  $("select#control").on('change', function() {
    const selected = $("select#control").find(":selected").val();
    toggle_patch(selected);
  });
  if ('<%= $selected->{control} %>' === 'patch') {
    toggle_patch('patch');
  }
  else {
    toggle_patch('not-patch');
  }
  if ('<%= $selected->{group} %>') {
    populate("group", "parameter");
    $("#parameter").val('<%= $selected->{parameter} %>');
  }
  if ('<%= $selected->{group_to} %>') {
    populate("group_to", "param_to");
    $("#param_to").val('<%= $selected->{param_to} %>');
  }
});
</script>


@@ layouts/default.html.ep
% title 'Synth::Config';
<!DOCTYPE html>
<html lang="en">
  <head>
    <title><%= title %></title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-EVSTQN3/azprG1Anm3QDgpJLIm9Nao0Yz1ztcQTwFspd3yD65VohhpuuCOmLASjC" crossorigin="anonymous">
    <link href="/css/fontawesome.css" rel="stylesheet">
    <link href="/css/solid.css" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/jquery@3.7.0/dist/jquery.min.js"></script>
    <style>
      a:hover, a:visited, a:link, a:active { text-decoration: none; }
    </style>
  </head>
  <body>
    <div class="container">
      <p></p>
% if (flash('error')) {
    %= tag h3 => (style => 'color:red') => flash('error')
% }
% if (flash('message')) {
    %= tag h3 => (style => 'color:green') => flash('message')
% }
      <h1><a href="<%= url_for('index') %>"><%= title %></a></h1>
      <%= content %>
      <p></p>
      <div id="footer" class="text-muted small">
        <hr>
        Copyright © 2023 All rights reserved
        <br>
        Built by <a href="http://gene.ology.net/">Gene</a>
        with <a href="https://www.perl.org/">Perl</a> and
        <a href="https://mojolicious.org/">Mojolicious</a>
      </div>
      <p></p>
    </div>
  </body>
</html>

