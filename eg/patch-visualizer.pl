#!/usr/bin/env perl
use strict;
use warnings;

use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(Synth-Config); # local author libs

use Synth::Config ();

use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use List::Util qw(first);
use YAML qw(LoadFile);

my %opt = ( # defaults:
    model     => undef, # e.g. 'Modular'
    config    => undef, # n.b. set below if not given
    patch     => undef, # e.g. 'Simple 001'
);
GetOptions(\%opt,
    'model=s',
    'config=s',
    'patch=s',
);

my $model_name = $opt{model};

die "Usage: perl $0 --model='Modular' [--patch='Simple 001']\n"
    unless $model_name;

$opt{config} ||= "eg/$model_name.yaml";
die "Invalid model config\n" unless -e $opt{config};
my $config = LoadFile($opt{config});

my $synth = Synth::Config->new(model => $model_name);

for my $patch ($config->{patches}->@*) {
    my $patch_name = $patch->{patch};

    next if $opt{patch} && $patch_name ne $opt{patch};

    my $settings = $synth->search_settings(name => $patch_name);

    if ($settings && @$settings) {
        print "Removing $patch_name setting from $model_name\n";
        $synth->remove_settings(name => $patch_name);
    }

    for my $setting ($patch->{settings}->@*) {
        print "Adding $patch_name setting to $model_name\n";
        $synth->make_setting(name => $patch_name, %$setting);
    }
    $settings = $synth->search_settings(name => $patch_name);

    my $g = $synth->graphviz(
      $settings,
      {
        model_name => $model_name,
        patch_name => $patch_name,
        render     => 1,
      }
    );
}
