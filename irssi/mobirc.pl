use strict;
use warnings;
use utf8;
use Encode;

use Irssi;
use AnyEvent;

use App::Mobirc;
use App::Mobirc::Util;

our $mobirc;

{ package Irssi::Nick }

Irssi::settings_add_str('mobirc', 'mobirc_config_path', '');
Irssi::settings_add_bool('mobirc', 'mobirc_auto_start', 0);

Irssi::command_bind( mobirc => sub {
    my ($data) = @_;

    if (($data || '') =~ /start/) {
        if ($mobirc) {
            Irssi::print('mobirc is already started!');
            return;
        }
        start();
    }
    elsif (($data || '') =~ /stop/) {
        stop();
    }
});

Irssi::signal_add("message $_" => bind_signal("irssi_$_"))
    for qw/public private own_public own_private
           join part quit kick nick own_nick invite topic/;

Irssi::signal_add("message irc $_" => bind_signal("irssi_irc_$_"))
    for qw/op_public own_wall own_action action own_notice notice own_ctcp ctcp/;


# autostart
if (Irssi::settings_get_bool('mobirc_auto_start')) {
    start();
}

sub bind_signal {
    my $sub = __PACKAGE__->can(shift) or return sub {};

    return sub {
        $sub->(@_);
    };
}

sub nick_name {
    my $server = Irssi::active_server() or return '';
    $server->{nick};
}

sub start {
    my $conffname = Irssi::settings_get_str('mobirc_config_path');
    unless ($conffname) {
        Irssi::print('mobirc_config_path is not defined, please do "/set mobirc_config_path your_ini_path" first');
        return;
    }
    unless (-f $conffname && -r _) {
        Irssi::print("file does not exist: $conffname");
        return;
    }

    eval { $mobirc = App::Mobirc->new(config => $conffname) };
    if ($@) {
        Irssi::print("can't initialize mobirc: $@");
        return;
    }

    $mobirc->add_channel( App::Mobirc::Model::Channel->new(name => U '*server*') );
    for my $channel (Irssi::channels()) {
        my $channel_name = normalize_channel_name(U $channel->{name});
        $mobirc->add_channel( App::Mobirc::Model::Channel->new(name => $channel_name) );
    }

    $App::Mobirc::Util::nick = nick_name();

    $mobirc->register_hook(
        process_command => ( undef, sub {
            my ( $self, $global_context, $command, $channel ) = @_;

            ($channel) = grep { $_->{name} eq $channel->name } Irssi::channels();
            if ($channel) {
                if ($channel->{name} =~ /^[#*%]/) {
                    if ($command =~ m{^/me (.*)}) {
                        my $body = $1;
                        $channel->{server}->command("ACTION $channel->{name} $body")
                            if $body;
                    }
                    else {
                        $channel->{server}->command("MSG $channel->{name} $command");
                    }
                }
                return true;
            }
            return false;
        })
    );

    $mobirc->run_hook('run_component');
    Irssi::print('mobirc started');
}

sub stop {
    undef $mobirc;
}

sub add_message {
    my ($channel, $who, $body, $class) = map { U $_ } @_;

    $channel = $mobirc->get_channel(normalize_channel_name($channel))
        or return;

    my $message = App::Mobirc::Model::Message->new(
        who   => $who,
        body  => $body,
        class => $class,
    );
    $channel->add_message($message);
}

sub irssi_public {
    my ($server, $msg, $nick, $address, $target) = @_;

    add_message($target, $nick, $msg, 'public');
}

sub irssi_own_public {
    my ($server, $msg, $target) = @_;
    add_message($target, $server->{nick}, $msg, 'public');
}

sub irssi_join {
    my ($server, $channel, $nick, $address) = @_;

    $channel = normalize_channel_name(U $channel);

    unless ($server->{nick} eq $nick) {
        add_message( $channel, undef, "$nick joined", 'join' );
    }
}

sub irssi_part {
    my ($server, $channel, $nick, $address, $reason) = @_;

    $channel = normalize_channel_name(U $channel);
    if ($server->{nick} eq $nick) {
        delete $mobirc->{channels}{ $channel };
    }
    else {
        my $msg = "$nick part";
        $msg .= " ($reason)" if $reason;
        add_message( $channel, undef, $msg, 'leave' );
    }
}

sub irssi_own_nick {
    my ($server, $newnick, $oldnick, $address) = @_;
    $App::Mobirc::Util::nick = $newnick;
}

sub irssi_topic {
    my ($server, $channel, $topic, $nick, $address) = @_;

    $channel = $mobirc->get_channel(normalize_channel_name(U $channel))
        or return;
    $channel->topic(U $topic);

    add_message( $channel->name, undef, "$nick set topic: $topic", 'topic' );
}

sub irssi_irc_action {
    my ($server, $msg, $nick, $address, $target) = @_;

    $msg = sprintf('* %s %s', $nick, $msg);
    add_message( $target, '', $msg, 'ctcp_action' );
}

sub irssi_irc_own_action {
    my ($server, $msg, $target) = @_;

    $msg = sprintf('* %s %s', $server->{nick}, $msg);
    add_message( $target, '', $msg, 'ctcp_action' );
}

sub irssi_irc_notice {
    my ($server, $msg, $nick, $address, $target) = @_;

    add_message($target, $nick, $msg, 'notice');
}

sub irssi_irc_own_notice {
    my ($server, $msg, $target) = @_;

    add_message($target, $server->{nick}, $msg, 'notice');
}

sub irssi_irc_snotice {
    my ($server, $msg, $nick, $address, $target) = @_;
    return unless $msg =~ /^\d/; # messages only

    add_message('*server*', undef, $msg, 'snotice');
}
