#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use Pod::Usage;

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
pod2usage( -exitval => 0, -verbose => 2 ) if $opts{man};

if (my @missing = grep !defined($opts{$_}), qw(model)) {
    die 'Missing: ' . join(', ', @missing);
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
