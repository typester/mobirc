package Mobirc::Plugin::Component::Twitter;
use strict;
use warnings;
use POE::Component::Client::Twitter;
use Mobirc::Channel;
use Mobirc::Util;
use POE;
use POE::Sugar::Args;

sub register {
    my ($class, $global_context, $conf) = @_;

    DEBUG "register twitter client component";
    $global_context->register_hook(
        'run_component' => sub { _init($conf, shift) },
    );

    $conf->{channel} ||= U '#twitter';
    $conf->{alias} ||= 'twitter';
    $conf->{screenname} ||= $conf->{username};
    $conf->{friend_timeline_interval} ||= 20;
}

sub _init {
    my ( $conf, $global_context ) = @_;

    my $twitter = POE::Component::Client::Twitter->spawn( %{ $conf } );

    $global_context->add_channel(
        Mobirc::Channel->new( $global_context, $conf->{channel}, ),
    );

    POE::Session->create(
        inline_states => {
            _start => sub {
                my $poe = sweet_args;
                $twitter->yield('register');
                $poe->kernel->delay( 'delay_friend_timeline' =>
                      $conf->{friend_timeline_interval} );
            },
            delay_friend_timeline => sub {
                my $poe = sweet_args;
                $twitter->yield('friend_timeline');
                $poe->kernel->delay( 'delay_friend_timeline' => 5 );
            },
            'twitter.friend_timeline_success' => sub {
                my $poe = sweet_args;
                my $ret = $poe->args->[0] || [];
                my $channel = $global_context->get_channel( $conf->{channel} );
                DEBUG "twitter friend timeline SUCCESSS!!";
                DEBUG "got lines: " . scalar(@$ret);
                for my $line ( reverse @{$ret} ) {
                    my $who  = U $line->{user}->{screen_name};
                    my $body = U $line->{text};

                    DEBUG "GOT STATUS IS: $body($who)";

                    next if $conf->{screenname} eq $who;

                    $channel->add_message(
                        Mobirc::Message->new(
                            who => $who,
                            body => $body,
                        )
                    );
                }
            },
        }
    );
}

1;
__END__

=head1 NAME

Mobirc::Plugin::Component::Twitter - twitter component for mobirc

=head1 SYNOPSIS

  - module: Mobirc::Plugin::Component::Twitter
    config:
      username: foo
      password: bar
      screenname: bababa
      channel: #mytwitter

=head1 LIMITATION

read only. you cannot post to twitter ;-(

