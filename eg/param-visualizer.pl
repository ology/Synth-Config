#!/usr/bin/env perl
use strict;
use warnings;

use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(Synth-Config); # local author libs

use Synth::Config ();

use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use Graph::Easy ();
use File::Slurper qw(write_text);
use YAML qw(LoadFile);

my %opt = ( # defaults:
    model  => undef, # e.g. 'Modular'
    config => undef, # n.b. set below if not given
);
GetOptions(\%opt,
    'model=s',
    'config=s',
);

my $model_name = $opt{model};

die "Usage: perl $0 --model='My modular'\n" unless $model_name;

$opt{config} ||= "eg/$model_name.yaml";
die "Invalid model config\n" unless -e $opt{config};
my $config = LoadFile($opt{config});
#warn __PACKAGE__,' L',__LINE__,' ',ddc($config, {max_width=>128});exit;

my $synth = Synth::Config->new(model => $model_name);

for my $patch ($config->{patches}->@*) {
    my $patch_name = $patch->{patch};

    my $settings = $synth->search_settings(name => $patch_name);
    unless (@$settings) {
        for my $setting ($patch->{settings}->@*) {
            print "Adding $patch_name setting to $model_name...\n";
            $synth->make_setting(name => $patch_name, %$setting);
        }

        $settings = $synth->search_settings(name => $patch_name);
    }

    my $g = Graph::Easy->new;
    my (%nodes, %edges);

    for my $s (@$settings) {
          my $setting = (values(%$s))[0];
          my $from = $setting->{group};
          unless ($nodes{$from}) {
              ($nodes{$from}) = $g->add_group($from);
              $nodes{$from}->set_attribute('label', '');
              $nodes{$from}->add_node($from);
          }
          if ($setting->{control} eq 'patch') {
              my $to = $setting->{group_to};
              unless ($nodes{$to}) {
                  my ($to_group) = $g->add_group($to);
                  $nodes{$to} = $to_group;
              }
              my $label = "$setting->{parameter} to $setting->{param_to}";
              my $key = "$from $setting->{parameter} to $to $setting->{param_to}";
              $g->add_edge_once($from, $to, $label);
          }
          else {
              my $label = "$setting->{parameter}: $setting->{value}$setting->{unit}";
              $nodes{$from}->add_node($label);
          }
    }

    (my $model = $model_name) =~ s/\W/_/g;
    (my $patch = $patch_name) =~ s/\W/_/g;
    my $filename = "$model-$patch.png";

    write_text("$model-$patch.svg", $g->as_svg);
}
