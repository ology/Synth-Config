#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use Pod::Usage;
use IO::Prompt::Tiny qw(prompt);

use lib map { "$ENV{HOME}/sandbox/$_/lib" } qw(Synth-Config);
use Synth::Config ();

pod2usage(1) unless @ARGV;

my %opts = (
    model  => undef,
    dbname => undef,
);
GetOptions( \%opts,
    'model=s',
    'dbname=s',
) or pod2usage(2);

pod2usage(1) if $opts{help};
pod2usage(-exitval => 0, -verbose => 2) if $opts{man};

if (my @missing = grep !defined($opts{$_}), qw(model)) {
    die 'Missing: ' . join(', ', @missing);
}

my $synth = Synth::Config->new(model => $opts{model});

my $name = prompt('What is the name of this setting?', 'required');
die 'No name given' unless $name;

my @keys = qw(group parameter control bottom top value unit is_default);

my $response;

my $counter = 0;

OUTER: while (1) {
    $counter++;
    my %parameters;
    INNER: for my $key (@keys) {
        $response = prompt("$counter. Value for $key? (enter to skip, q to quit)", 'enter');
        if ($response eq 'q') {
            last OUTER;
        }
        elsif ($response eq 'enter') {
            next INNER;
        }
        else {
            $parameters{$key} = $response;
        }
    }
    if ($parameters{name} && keys(%parameters) > 1) {
        my $id = $synth->make_setting(%parameters);
    }
    $response = prompt('Enter for another setting (q to quit)', 'enter');
    if ($response eq 'q') {
        last OUTER;
    }
}

__END__

=head1 NAME

synth-config.pl - Save and recall synth settings

=head1 SYNOPSIS

  synth-config.pl --model=Something [--dbname=something.db]

=head1 OPTIONS

=over 4

=item B<model>

The required synthesizer model name.

=item B<dbname>

The name of the SQLite database in which to save settings.

=back

=head1 DESCRIPTION

B<synth-config.pl> loops through the settings for a synthesizer,
prompting for values.

=cut
