#!perl

use v5.24;
use warnings;
use experimental qw[ signatures lexical_subs postderef ];

use Data::Dumper;

use ELO::Loop;

use constant DEBUG => $ENV{DEBUG} // 0;

sub timer ($this, $timeout, $callback) {
    warn ">> Create Timer with timeout($timeout)" if DEBUG;

    my $timer;
    $timer = sub {
        warn "Timer tick ... timeout($timeout)" if DEBUG;
        if ($timeout <= 0) {
            warn ">> Timeout done!" if DEBUG;
            $this->loop->next_tick(sub {
                $this->send( @$callback );
            });
        }
        else {
            warn ">> Still waiting ..." if DEBUG;
            $timeout--;
            $this->loop->next_tick($timer)
        }
    };

    $timer->();
}

sub Responder ($this, $msg) {
    warn $this->pid.' : ENTERED';

    warn Dumper $msg;
}

sub init ($this, $msg) {
    warn $this->pid.' : ENTERED';
    my $r = $this->spawn( Responder => \&Responder );

    timer( $this, 0, [ $r, ['Hello ... timeout(0)'] ] );
    timer( $this, 1, [ $r, ['Hello ... timeout(1)'] ] );
    timer( $this, 2, [ $r, ['Hello ... timeout(2)'] ] );
}

ELO::Loop->new->run( \&init );

1;
