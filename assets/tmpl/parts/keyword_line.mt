? my $message = shift;
?= include('parts/irc_message', $message);
<? if (my $channel = $message->channel) { ?>
    (
        <a href="/mobile/channel?channel=<?= $channel->name_urlsafe_encoded ?>">
            <?= $channel->name ?>
        </a>
    )
<? } ?>
<br />
