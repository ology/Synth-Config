use Mojo::Base -strict;

use Mojo::File qw(curfile);
use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new(curfile->dirname->sibling('mojo-ui.pl'));

subtest page_load => sub {
  $t->get_ok($t->app->url_for('index'))
    ->status_is(200)
  ;
};

done_testing();
