#!/usr/bin/env perl
use strict;
use warnings;

use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(Synth-Config); # local author libs
use Synth::Config ();
use Getopt::Long qw(GetOptions);

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

my $synth = Synth::Config->new(model => $model_name);

my $patches = $synth->import_yaml(
    file    => $opt{config},
    patches => [ $opt{patch} ],
);

for my $patch (@$patches) {
    my $settings = $synth->search_settings(name => $patch);
    $synth->graphviz(
        settings   => $settings,
        model_name => $model_name,
        patch_name => $patch,
        render     => 1,
    );
}
