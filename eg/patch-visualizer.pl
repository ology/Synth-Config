#!/usr/bin/env perl
use strict;
use warnings;

use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(Synth-Config); # local author libs

use Synth::Config ();

use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use GraphViz2 ();
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
    # TODO if settings then update
    unless (@$settings) {
        for my $setting ($patch->{settings}->@*) {
            print "Adding $patch_name setting to $model_name...\n";
            $synth->make_setting(name => $patch_name, %$setting);
        }

        $settings = $synth->search_settings(name => $patch_name);
    }

    my $g = GraphViz2->new(
        global => { directed => 1 },
        node   => { shape => 'oval' },
        edge   => { color => 'grey' },
    );

    my %nodes;
    my %edges;
    my %sets;
    my %labels;

    # collect settings by group
    for my $s (@$settings) {
        my $setting = (values(%$s))[0];
        my $from = $setting->{group};
        push $sets{$from}->@*, $setting;
    }
    # create node label
    for my $s (@$settings) {
        my $setting = (values(%$s))[0];
        my $from = $setting->{group};
        my @label = ($from);
        for my $group ($sets{$from}->@*) {
            next if $group->{control} eq 'patch';
            push @label, "$group->{parameter} = $group->{value}$group->{unit}";
        }
        my $label = join "\n", @label;
        $labels{$from} = $label;
    }

    for my $s (@$settings) {
        my $setting = (values(%$s))[0];
        next unless $setting->{control} eq 'patch' || $setting->{group_to};
        # create edge
        my $from  = $setting->{group};
        my $to    = $setting->{group_to};
        my $param = "$from $setting->{parameter} to $to $setting->{param_to}";
        my $label = "$setting->{parameter} to $setting->{param_to}";
        $to = $labels{$to};
        $from = $labels{$from};
        $g->add_node(name => $from) unless $nodes{$from}++;
        $g->add_node(name => $to) unless $to && $nodes{$to}++;
        $g->add_edge(
            from  => $from,
            to    => $to,
            label => $label,
        ) unless $edges{$param}++;
    }

    (my $model = $model_name) =~ s/\W/_/g;
    (my $patch = $patch_name) =~ s/\W/_/g;
    my $filename = "$model-$patch.png";

    $g->run(format => 'png', output_file => $filename);
}
