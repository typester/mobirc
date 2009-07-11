use t::Utils;
use App::Mobirc;

use Test::Base;
eval q{ use String::IRC };
plan skip_all => "String::IRC is not installed." if $@;

global_context->load_plugin( { module => 'MessageBodyFilter::IRCColor', config => { no_decorate => 1} } );

filters {
    input => ['eval', 'decorate_irc_color'],
};

sub decorate_irc_color {
    my $x = shift;
    ($x,) = global_context->run_hook_filter('message_body_filter', $x);
    return $x;
}

run_is input => 'expected';

__END__

===
--- input: String::IRC->new('world')->yellow('green')
--- expected: world

===
--- input: String::IRC->new('world')->red('green')
--- expected: world

