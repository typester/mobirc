use t::Utils;
use Test::More;
use App::Mobirc::Util;
use File::Temp;
plan tests => 1;

my $tmpfh = File::Temp->new(UNLINK => 0);
my $pid = fork();
if ($pid == 0) {
    # child
    daemonize($tmpfh->filename);
    exit(0);
} elsif ($pid > 0) {
    # parent
    wait;
    sleep 3; # ad-hoc
    like slurp($tmpfh->filename), qr{^\d+\n$}, 'pid file is exist';
    unlink $tmpfh->filename;
} else {
    die "fork error";
}

sub slurp {
    my $fname = shift;

    open my $fh, q{<}, $fname or die $!;
    my $dat = join '', <$fh>;
    close $fh;

    return $dat;
}

