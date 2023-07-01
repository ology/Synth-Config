use Mojo::Base -strict;

use Mojo::File qw(curfile);
use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new(curfile->dirname->sibling('mojo-ui.pl'));

subtest index => sub {
  $t->get_ok($t->app->url_for('index'))
    ->text_is('html head title' => 'Synth::Config', 'has page title')
    ->text_is('body div h1 a' => 'Synth::Config', 'displays page title')
    ->element_exists('select[name="model"]', 'has model select')
    ->element_exists('select[name="name"]', 'has name select')
    ->element_exists('select[name="group"]', 'has group select')
    ->element_exists('input[name="fields"]', 'has fields input')
    ->element_exists('button[id="search"]', 'has search btn')
    ->element_exists('a[id="new_model"]', 'has new_model btn')
    ->status_is(200)
  ;
};

done_testing();