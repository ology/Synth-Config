#!/usr/bin/env perl
use Mojolicious::Lite -signatures;

use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);
use IO::Prompt::Tiny qw(prompt);
use Term::Choose ();

use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(Synth-Config);
use Synth::Config ();

get '/' => sub ($c) {
  my $model = $c->param('model') || 'Moog Matriarch';
  my $group = $c->param('group') || 'arp_seq';
  my $synth = Synth::Config->new(model => $model);
  # get a specs config file for the synth model
  my $set = './eg/' . $synth->model . '.set';
  my $specs = -e $set ? do $set : undef;
  # get the known groups if there are specs
  my $groups = $specs ? $specs->{group} : undef;
  $groups = [ sort @$groups ] if $groups;
  my $settings = $synth->search_settings(group => $group);
  $c->render(
    template => 'index',
    model    => $model,
    group    => $group,
    groups   => $groups,
    settings => ddc $settings,
  );
} => 'index';

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Synth::Config';
<form action="<%= url_for('index') %>" method="get">
  <label for="model">Model:</label>
  <input name="model" id="model" value="<%= $model %>">
  <label for="group">Module:</label>
  <select name="group" id="group">
% for my $g (@$groups) {
    <option value="<%= $g %>" <%= $g eq $group ? 'selected' : '' %>><%= ucfirst $g %></option>
% }
  </select>
  <input type="submit" value="Submit">
</form>
<pre><%= $settings %></pre>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
