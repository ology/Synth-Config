#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

use_ok 'Synth::Config';

my $obj = new_ok 'Synth::Config' => [
  model   => 'Moog Matriarch',
  dbname  => 'test.db',
  verbose => 1,
];

subtest defaults => sub {
  is $obj->model, 'moog_matriarch', 'model';
  is $obj->verbose, 1, 'verbose';
};

subtest settings => sub {
  my $name   = 'Test setting!',
  my $expect = {
    group      => 'filter',
    parameter  => 'cutoff',
    control    => 'knob',
    bottom     => 20,
    top        => 20_000,
    value      => 200,
    unit       => 'Hz',
    is_default => 0,
  };
  # make an initial setting
  my $id = $obj->make_setting(%$expect, name => $name);
  ok $id, "id: $id";
  # recall that setting
  my $setting = $obj->recall_setting(id => $id);
  is_deeply $setting, { settings => $expect }, 'settings';
  # update a single field in the setting
  my $got = $obj->make_setting(id => $id, is_default => 1);
  is $got, $id, 'updated setting';
  # recall that same setting
  $setting = $obj->recall_setting(id => $id);
  is keys(%{ $setting->{settings} }), keys(%$expect), 'settings all there';
  # check the updated field
  ok $setting->{settings}{is_default}, 'is_default';
  # another!
  $expect = {
    group      => 'modulation',
    parameter  => 'wave out',
    control    => 'patch',
    bottom     => 0,
    top        => 1,
    value      => 1,
    unit       => 'boolean',
    is_default => 0,
  };
  # make a second setting
  my $id2 = $obj->make_setting(%$expect, name => $name);
  is $id2, $id + 1, "id: $id2";
  # recall that setting
  $setting = $obj->recall_setting(id => $id2);
  is_deeply $setting, { settings => $expect }, 'settings';
  # update a single field in the setting
  my $got2 = $obj->make_setting(id => $id2, is_default => 1);
  is $got2, $id + 1, 'updated setting';
  # recall that same setting
  $setting = $obj->recall_setting(id => $got2);
  is keys(%{ $setting->{settings} }), keys(%$expect), 'settings all there';
  # check the updated field
  ok $setting->{settings}{is_default}, 'is_default';
};

subtest cleanup => sub {
  ok -e 'test.db', 'db exists';
  unlink 'test.db';
  unlink 'test.db-shm';
  unlink 'test.db-wal';
  ok !-e 'test.db', 'db unlinked';
};

done_testing();
