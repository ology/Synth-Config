use Mojo::Base -strict;

use Mojo::File qw(curfile);
use Test::Mojo;
use Test::More;

use constant SETTINGS => './eg/public/settings/';

my $t = Test::Mojo->new(curfile->dirname->sibling('mojo-ui.pl'));

$t->ua->max_redirects(1);

my $model  = 'Testing';
my $name   = 'Foo';
my $groups = 'a,b,c';
my @groups = split ',', $groups;
my %params;
@params{@groups} = ('1,2', '3,4', '5,6');

subtest index => sub {
  $t->get_ok($t->app->url_for('index'))
    ->status_is(200)
    ->text_is('html head title' => 'Synth::Config', 'has page title')
    ->text_is('body div h1 a' => 'Synth::Config', 'displays page title')
    ->element_exists('select[name="model"]', 'has model select')
    ->element_exists('select[name="name"]', 'has name select')
    ->element_exists('select[name="group"]', 'has group select')
    ->element_exists('input[name="fields"]', 'has fields input')
    ->element_exists('button[id="search"]', 'has search btn')
    ->element_exists('a[id="new_model"]', 'has new_model btn')
  ;
  $t->get_ok($t->app->url_for('index')->query(model => $model))
    ->status_is(200)
    ->element_exists('a[id="new_setting"]', 'has new_setting btn')
    ->element_exists('a[id="edit_model"]', 'has edit_model btn')
    ->element_exists('a[id="remove_model"]', 'has remove_model btn')
  ;
};

subtest new_model => sub {
  $t->get_ok($t->app->url_for('model'))
    ->status_is(200)
    ->element_exists('input[name="model"]', 'has model input')
    ->element_exists('input[name="groups"]', 'has groups input')
    ->element_exists('button[id="new_model"]', 'has new_model btn')
    ->element_exists('a[id="cancel"]', 'has cancel btn')
  ;
  $t->post_ok($t->app->url_for('model'), form => { model => $model, groups => $groups })
    ->status_is(200)
    ->element_exists(qq/input[name="model"][value="$model"]/, 'has model value')
    ->element_exists(qq/input[name="groups"][value="$groups"]/, 'has groups value')
    ->element_exists(qq/input[name="group"][id="a"]/, 'has param input')
    ->element_exists(qq/input[name="group"][id="b"]/, 'has param input')
    ->element_exists(qq/input[name="group"][id="c"]/, 'has param input')
  ;
};

subtest edit_model => sub {
  $t->get_ok($t->app->url_for('edit_model')->query(model => $model))
    ->status_is(200)
    ->element_exists(qq/input[name="model"][value="$model"]/, 'has model value')
    ->element_exists(qq/input[name="groups"][value="$groups"]/, 'has groups value')
    ->element_exists(qq/input[name="group"][id="a"]/, 'has param input')
    ->element_exists(qq/input[name="group"][id="b"]/, 'has param input')
    ->element_exists(qq/input[name="group"][id="c"]/, 'has param input')
  ;
  $t->post_ok($t->app->url_for('model'), form => { model => $model, groups => $groups, group => [ sort values %params ] })
    ->content_like(qr/Update parameters successful/)
    ->status_is(200)
  ;
  $t->get_ok($t->app->url_for('edit_model')->query(model => $model))
    ->status_is(200)
    ->element_exists(qq/input[name="model"][value="$model"]/, 'has model value')
    ->element_exists(qq/input[name="groups"][value="$groups"]/, 'has groups value')
    ->element_exists(qq/input[name="group"][id="a"][value="$params{a}"]/, 'has param value')
    ->element_exists(qq/input[name="group"][id="b"][value="$params{b}"]/, 'has param value')
    ->element_exists(qq/input[name="group"][id="c"][value="$params{c}"]/, 'has param value')
  ;
};

subtest new_setting => sub {
  $t->get_ok($t->app->url_for('edit')->query(model => $model))
    ->status_is(200)
    ->element_exists(qq/input[name="model"][value="$model"]/, 'has model value')
    ->element_exists('input[name="name"]', 'has name input')
    ->element_exists('select[name="group"]', 'has group select')
    ->element_exists('select[name="parameter"]', 'has parameter select')
    ->element_exists('select[name="control"]', 'has control select')
    ->element_exists('select[name="bottom"]', 'has bottom select')
    ->element_exists('select[name="top"]', 'has top select')
    ->element_exists('select[name="group_to"]', 'has group_to select')
    ->element_exists('select[name="param_to"]', 'has param_to select')
    ->element_exists('input[name="value"]', 'has value input')
    ->element_exists('select[name="unit"]', 'has unit select')
    ->element_exists('input[type="radio"][name="is_default"]', 'has is_default radio')
    ->element_exists('button[type="submit"]', 'has submit btn')
    ->element_exists('a[id="cancel"]', 'has cancel btn')
  ;
  my $form = {
    model      => $model,
    name       => $name,
    group      => $groups[0],
    parameter  => substr($params{ $groups[0] }, 0, 1),
    control    => 'knob',
    bottom     => 0,
    top        => 6,
    value      => 3,
    unit       => 'Hz',
    is_default => 0,
  };
  $t->post_ok($t->app->url_for('update'), form => $form)
    ->content_like(qr/Update setting successful/)
    ->status_is(200)
  ;
  $t->get_ok($t->app->url_for('edit')->query(%$form))
    ->status_is(200)
    ->element_exists(qq/input[name="model"][value="$model"]/, 'has model value')
    ->element_exists(qq/input[name="name"][value="$name"]/, 'has name value')
    ->element_exists('select[name="group"]:has(option[selected][value="a"])', 'has group value')
    ->element_exists('select[name="parameter"]:has(option[selected][value="1"])', 'has parameter value')
    ->element_exists('select[name="control"]:has(option[selected][value="knob"])', 'has control value')
    ->element_exists('select[name="bottom"]:has(option[selected][value="0"])', 'has bottom value')
    ->element_exists('select[name="top"]:has(option[selected][value="6"])', 'has top value')
    ->element_exists('select[name="group_to"]:not(:has(option[selected]))', 'no group_to selected')
    ->element_exists('select[name="param_to"]:not(:has(option[selected]))', 'no param_to selected')
    ->element_exists('input[name="value"][value="3"]', 'has value value')
    ->element_exists('select[name="unit"]:has(option[selected][value="Hz"])', 'has unit value')
    ->element_exists('input[name="is_default"][value="0"]', 'has is_default value')
  ;
};

subtest cleanup => sub {
  $t->get_ok($t->app->url_for('remove')->query(id => 1, model => $model, name => $name))
    ->status_is(200)
  ;
  $t->get_ok($t->app->url_for('remove')->query(model => $model))
    ->status_is(200)
  ;
  (my $model_id = $model) =~ s/\W/_/g;
  $model_id = lc $model_id;
  ok !-e SETTINGS . $model_id . '.dat', 'no settings file';
};

done_testing();
