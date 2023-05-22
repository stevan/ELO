#!perl

use v5.36;
use experimental 'try';

use Test::More;
use Test::Differences;
use Test::ELO;

use Data::Dumper;

use ok 'ELO::Stream';
use ok 'ELO::Loop';
use ok 'ELO::Timers', qw[ ticker ];

my $log = Test::ELO->create_logger;

package My::Source {
    use v5.36;

    use parent 'UNIVERSAL::Object';
    use roles  'ELO::Stream::API::Source';
    use slots (
        start_at => sub { 0 },
        up_to    => sub { 10 },
        # ...
        _count => sub {},
    );

    sub BUILD ($self, $) {
        $self->{_count} = $self->{start_at};
    }

    sub has_next ($self) { $self->{_count} <= $self->{up_to} }
    sub next     ($self) { $self->{_count}++ }

    sub to ($self, $sink) {
        My::Stream->new(
            source => $self,
            sink   => $sink
        )
    }
}

package My::Sink {
    use v5.36;

    use parent 'UNIVERSAL::Object';
    use roles  'ELO::Stream::API::Sink';
    use slots (
        label => sub {}
    );

    sub on_complete ($self) {
        say "($self) Completed";
    }

    sub on_next ($self, $item) {
        say "($self) Next($item)";
    }

    sub on_error ($self, $e) {
        say "($self) Error($e)";
    }

    sub map ($self, $f) {
        My::Flow::Map->new( f => $f, sink => $self )
    }
}

package My::Flow::Map {
    use v5.36;

    use parent 'UNIVERSAL::Object';
    use roles  'ELO::Stream::API::Sink';
    use slots (
        sink => sub {},
        f    => sub {},
    );

    sub on_complete ($self) {
        say "$self Completed";
        $self->{sink}->on_complete;
    }

    sub on_next ($self, $item) {
        say "$self Next($item)";
        $self->{sink}->on_next( $self->{f}->( $item ) );
    }

    sub on_error ($self, $e) {
        say "$self Error($e)";
        $self->{sink}->on_error( $e );
    }
}

package My::Stream {
    use v5.36;
    use experimental 'try';

    use parent 'UNIVERSAL::Object';
    use slots (
        source => sub {},
        sink   => sub {},
    );

    sub source ($self, $source) {
        $self->{source} = $source;
        $self;
    }

    sub sink ($self, $sink) {
        $self->{sink} = $sink;
        $self;
    }

    sub run ($self, $loop) {

        $loop->next_tick(sub {
            if ( $self->{source}->has_next ) {

                try {
                    $self->{sink}->on_next( $self->{source}->next );
                } catch ($e) {
                    $self->{sink}->on_error( $e );
                }

                $loop->next_tick( __SUB__ );
            }
            else {
                $self->{sink}->on_complete;
            }
        });

        $self;
    }
}

sub init ($this, $msg) {

    My::Source->new( up_to => 10 + $_ )
              ->to( My::Sink->new->map( sub ($x) { sprintf '%03d' => $x } ) )
              ->run( $this->loop )
    for 0 .. 10;
}

ELO::Loop->run( \&init, logger => $log );

done_testing;

1;

__END__
