#!/usr/bin/env perl
use strict;
use warnings;

use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(Synth-Config);

use Synth::Config ();

use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use GraphViz2 ();
use YAML qw(LoadFile);

my %opt = ( # defaults:
    model   => undef, # e.g. 'Modular'
    config  => undef, # n.b. set below if not given
);
GetOptions(\%opt,
    'model=s',
    'config=s',
);

die "Usage: perl $0 --model='My modular' --setting='Simple 001'\n"
    unless $opt{model};

$opt{config} ||= $opt{model} . '.yaml';
die "Invalid model config\n" unless -e $opt{config};
my $config = LoadFile($opt{config});
warn __PACKAGE__,' L',__LINE__,' ',ddc($config, {max_width=>128});exit;

my @ids;

my $synth = Synth::Config->new(model => $opt{model});

for my $patch ($config->{patches}->@*) {
    my $settings = $synth->search_settings(name => $patch->{patch});
    unless (@$settings) {
        print "Adding $opt{setting} to $opt{model}...\n";

        for my $setting ($patch->{settings}->@*) {
            push @ids, $synth->make_setting(
                name => $patch->{patch},
                %$setting,
            );
        }

        $settings = $synth->search_settings(name => $patch->{patch});

        print "Done.\n";
    }
    print ddc $settings;
}

__END__
my $g = GraphViz2->new(
    global => { directed => 1 },
    node   => { shape => 'oval' },
    edge   => { color => 'grey' },
);

my %nodes;
my %edges;

for my $s (@$settings) {
      my $setting = (values(%$s))[0];
      my $from  = $setting->{group};
      my $to    = $setting->{group_to};
      my $param = "$setting->{parameter} to $setting->{param_to}";
      $g->add_node(name => $from) unless $nodes{$from}++;
      $g->add_node(name => $to)   unless $nodes{$to}++;
      $g->add_edge(from => $from, to => $to, label => $param)
          unless $edges{$param}++;
}

$g->run(format => 'png', output_file => "$0.png");
