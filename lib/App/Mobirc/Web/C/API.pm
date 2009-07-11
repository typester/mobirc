package App::Mobirc::Web::C::API;
use App::Mobirc::Web::C;

use Encode;
use JSON::Any;
my $j = JSON::Any->new( utf8 => 1, allow_nonref => 1 );

sub render_json {
    my $json = $j->encode(@_);
    HTTP::Engine::Response->new(
        content_type => 'application/json; charset=utf-8',
        body         => encode_utf8($json),
    );
}

sub render_channel {
    my $channel = $_[0];

    render_json({
        name     => $channel->name,
        topic    => $_->topic,
        messages => [map +{
            nick       => $_->who,
            nick_class => $_->who_class,
            body       => $_->body,
            class      => $_->class,
            time       => $_->time,
        }, $channel->message_log],
    });
}

sub dispatch_channels {
    my @channels = map +{
        name   => $_->name,
        topic  => $_->topic,
        unread => $_->unread_lines,
    }, server->channels;

    render_json(\@channels);
}

sub dispatch_channel {
    my $channel_name = shift || param('channel') or die "missing channel name";

    my $channel = server->get_channel($channel_name);
    $channel->clear_unread;
    render_channel($channel);
}

sub post_dispatch_channel {
    my $channel = param('channel') or die "missing channel name";
    my $msg     = param('msg') or die "missing message body";

    server->get_channel($channel)->post_command($msg);
    render_json('ok');
}

sub dispatch_keyword {
    dispatch_channel(server->keyword_channel);
}

1;
