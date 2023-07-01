use Mojo::Base -strict;

use Mojo::File qw(curfile);
use Test::Mojo;
use Test::More;

use constant SETTINGS => './eg/public/settings/';

my $t = Test::Mojo->new(curfile->dirname->sibling('mojo-ui.pl'));

$t->ua->max_redirects(1);

my $model = 'Testing';
my $groups = 'a,b,c';

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
    ->element_exists(qq/input[name="model"][value="$model"]/, 'has model input')
    ->element_exists(qq/input[name="groups"][value="$groups"]/, 'has groups input')
    ->element_exists(qq/input[name="group"][id="a"]/, 'has a param input')
    ->element_exists(qq/input[name="group"][id="b"]/, 'has b param input')
    ->element_exists(qq/input[name="group"][id="c"]/, 'has c param input')
  ;
};

subtest edit_model => sub {
  $t->get_ok($t->app->url_for('edit_model')->query(model => $model))
    ->status_is(200)
    ->element_exists(qq/input[name="model"][value="$model"]/, 'has model input')
    ->element_exists(qq/input[name="groups"][value="$groups"]/, 'has groups input')
    ->element_exists(qq/input[name="group"][id="a"]/, 'has a param input')
    ->element_exists(qq/input[name="group"][id="b"]/, 'has b param input')
    ->element_exists(qq/input[name="group"][id="c"]/, 'has c param input')
  ;
  $t->post_ok($t->app->url_for('model'), form => { model => $model, groups => $groups, group => [qw(1,2 3,4 5,6)] })
    ->content_like(qr/Update parameters successful/)
    ->status_is(200)
  ;
};

subtest cleanup => sub {
  $t->get_ok($t->app->url_for('remove')->query(model => $model))
    ->status_is(200)
  ;
  (my $model_id = $model) =~ s/\W/_/g;
  $model_id = lc $model_id;
  ok !-e SETTINGS . $model_id . '.dat', 'no settings file';
};

done_testing();
