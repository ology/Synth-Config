#!/usr/bin/env perl
use strict;
use warnings;

use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(Synth-Config); # local author libs

use Synth::Config ();

use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use GraphViz2 ();
use List::Util qw(first);
use YAML qw(LoadFile);

my %opt = ( # defaults:
    model     => undef, # e.g. 'Modular'
    config    => undef, # n.b. set below if not given
    patch     => undef, # e.g. 'Simple 001'
    extension => 'png',
);
GetOptions(\%opt,
    'model=s',
    'config=s',
    'patch=s',
    'extension=s',
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

    my $g = GraphViz2->new(
        global => { directed => 1 },
        node   => { shape => 'oval' },
        edge   => { color => 'grey' },
    );
    my (%edges, %sets, %labels);

    # collect settings by group
    for my $s (@$settings) {
        my $from = $s->{group};
        push $sets{$from}->@*, $s;
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

    # render patch edges
    for my $s (@$settings) {
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

    # save the file
    (my $model = $model_name) =~ s/\W/_/g;
    (my $patch = $patch_name) =~ s/\W/_/g;
    my $filename = "$model-$patch.$opt{extension}";
    $g->run(format => $opt{extension}, output_file => $filename);
}
