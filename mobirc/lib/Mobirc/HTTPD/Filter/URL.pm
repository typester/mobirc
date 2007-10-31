package Mobirc::HTTPD::Filter::URL;
use strict;
use warnings;
use URI::Find;
use URI::Escape;

sub process {
    my ( $class, $text, $conf ) = @_;

    URI::Find->new(
        sub {
            my ( $uri, $orig_uri ) = @_;

            my $out = qq{<a href="$uri" rel="nofollow" class="url">$orig_uri</a>};
            if ( $conf->{au_pcsv} ) {
                $out .=
                  sprintf( '<a href="device:pcsiteviewer?url=%s" rel="nofollow" class="au_pcsv">[PCSV]</a>',
                    $uri );
            }
            if ( $conf->{pocket_hatena} ) {
                $out .=
                  sprintf(
'<a href="http://mgw.hatena.ne.jp/?url=%s&noimage=0&split=1" rel="nofollow" class="pocket_hatena">[ph]</a>',
                    uri_escape($uri) );
            }
            return $out;
        }
    )->find( \$text );

    return $text;
}

1;