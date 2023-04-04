# ELO

### Event Loop Orchestra

This is an experiment in adding simple co-operative message passing style concurrency for Perl. 

```
use ELO::Loop;

sub HelloWorld ($this, $name) {
    say "Hello $name from ".$this->pid;
}

sub main ($this, $msg) {
    my $hello = $this->spawn('HelloWorld' => \&HelloWorld);
    $this->send( $hello, 'World');
}

ELO::Loop->new->run( \&main, () );

```

