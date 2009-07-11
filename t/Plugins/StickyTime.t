use t::Utils;
use Test::Base;
use App::Mobirc;

global_context->load_plugin( 'StickyTime' );

plan tests => 1*blocks;

filters {
    input => [qw/sticky/],
    expected => [qw/eval/],
};

run {
    my $block = shift;
    like $block->input, $block->expected;
};

sub sticky {
    my $html = shift;
    test_he_filter {
        my $req = shift;
        ($req, $html) = global_context->run_hook_filter('html_filter', $req, $html);
    };
    return $html;
}

__END__

===
--- input
<h1>foo</h1>
<!-- comment -->
<div class="bar">
    yeah
    <a href="/foo">foo</a>
</div>
--- expected
qr{<a href="/foo\?t=\d+">foo</a>}

