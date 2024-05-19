#!/usr/bin/env perl
use strict;
use warnings;

use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(Synth-Config); # local author libs
use Synth::Config ();
use Getopt::Long qw(GetOptions);

my %opt = (
    model  => undef, # e.g. 'Modular'
    patch  => undef, # e.g. 'Simple 001'
    config => undef, # n.b. set below if not given
);
GetOptions(\%opt,
    'model=s',
    'patch=s@',
    'config=s',
);

my $model = $opt{model};

die "Usage: perl $0 --model='Modular' [--patch='Simple 001' --patch='Simple 002']\n"
    unless $model;

$opt{config} ||= "eg/$model.yaml";
die "Invalid model config\n" unless -e $opt{config};

my $synth = Synth::Config->new(model => $model);

my $patches = $synth->import_yaml(
    file => $opt{config},
    defined $opt{patch} ? (patches => $opt{patch}) : (),
);

for my $patch_name (@$patches) {
    my $settings = $synth->search_settings(name => $patch_name);
    $synth->graphviz(
        settings   => $settings,
        model_name => $model,
        patch_name => $patch_name,
        render     => 1,
    );
}
