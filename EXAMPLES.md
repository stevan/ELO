# Fun ELO Examples

I have been accumulating a bunch of nice examples that use ELO in some way, this documents describes some of them in more detail.

> NOTE:
> Try adding the `ELO_LOOP_DUMP_STATS=1` env variable to see a
> dump of ELO statistics after the loop exits.

## 1.000.000 threads

Turns out ELO it is fairly performant as well, here is an example creating 1_000_000 actors. On my machine this will take just under a minute, and consumer just over 1.5GB of memory. Not too bad, and according to [this very artificial benchmark](https://pkolaczk.github.io/memory-consumption-of-async/), it puts `ELO` ahead of Go, Python and Elixir ... and pretty darn close to Java.

```perl
use v5.36;

use ELO::Loop;
use ELO::Actors qw[ setup IGNORE ];

sub Actor ($id) {
    state $loop; # the loop is always the same, ....

    setup sub ($this) {
        # so we save some time and effectively
        # turn it into a constant here ;)
        $loop //= $this->loop;

        # create a timer for sleep for 10 seconds and exit
        $loop->add_timer( 10, sub { $this->exit(0) });

        # we will have no messages to `match`, so
        # why waste an instance here, use IGNORE
        # so have a `receive` that does nothing
        IGNORE;
    };
}

sub init ($this, $) {
    my $countdown = 1_000_000;
    $this->spawn( Actor( $countdown-- ) ) while $countdown;
}

ELO::Loop->run( \&init );

```

And of course, this is perl, so we can do this all in one line. If you want to see timing info, use `/usr/bin/time` and watch the memory your preferred way. And yes, this fits in a tweet ;)
```
perl -Ilib -MELO::Loop -MELO::Actors=setup,IGNORE -E 'my$a=0;sub A($i){state$l;setup sub($t){print++$a,"\r";($l//=$t->loop)->add_timer(2,sub{print$a--,"\r";$t->exit(0)});IGNORE}};ELO::Loop->run(sub($t,$){say"START";my$x=10**6;$t->spawn(A($x))while$x--;say"\nEXIT"});say"\nDONE";'
```

## Fast Fibonacci

This is also a work in progress, it uses ELO to concurrently generate fibonacci numbers. Since calculating the fibonacci sequence, quite famously, does not lend it self to speed ups through concurrency, we can get fun and silly with it.

The simplest way to speed up the fibonacci sequence is to cache it. This results in each subsequent call (possibly) getting faster, bound primarily by the the choice of number to generate and previously generated numbers.

Bascially, a cold cache is not a very useful cache, and a luke-warm cache (partially filled) is only slightly better.

So, this example uses ELO actors to generate the fibonacci sequence as fast as possible. It does this by adding a random "jitter" or delay to the recursive calls, resulting in a unique ordering of the calls, which results in the cache being populated randomly.

Sometimes this works out well and the cache is populated in an advantagous way and our call is fast. Other times, not so much. What is most interesting about it is that it can result in the first call being reasonably performant, given an optimal random seed, whereas most syncronous fibonacci functions that use caching will still be slow on the first call.

### Particle Visualization

The particle example in `examples/particle.pl` is meant to be an example (albiet rather primative) of doing a simulation with ELO. This will randomly generate `$n` `Particle` actors at random locations and then proceed to perform a horribly incorrect gravity simulation in which all the particles bounce until they reach a state of rest. Once at rest the given `Particle` actor will exit.

> NOTE:
> This is not intended to be correct physics, only a
> test of the capabilities of ELO ,... just sayin ;)

*Positional Command Line Arguments:*

- the first argument is the number of particles
    - this defaults to 100
    - there is no limit on this, so you can ask for 100.000 if you want
        - it will just run really slow :)
- the second argument is the number of seconds to run the simulation
    - this defaults to 10 seconds
- the third argument is the gravity value
    - this defaults to 3
    - TIP: if you do a large number of particles, make this a fractional value (0.5 or lower)
        - this looks cooler because it makes the particles fall faster
            - no other reason, just looks cool


### PixelDisplay

Most of this has not yet been "actor"-fied, and it still a work in progress, but the demos are really fun.

#### Pixel Shader Example

A shader is basically a function that takes the x and y coordinates and returns RGB pixel information, and
this is run for every single pixel on the screen. They are fun, nuff said.

See the `Cool Tricks` section below some interesting things to do with this example.

> NOTE:
> The particular shader implemented is the one from this video: https://www.youtube.com/watch?v=f4s1h2YETNY
> The translation is a bit clunky without a `vec` type, but it works


#### Bit Block

This is a work in progress, for now it is mostly just painting images to the screen.

#### Key Frame

This is also a work in progress, it meant to be the start of a key-frame animation system.

#### WTF?!?!

The idea is to have a fully in-terminal, raster display that can be used for all kinds of things
from visualizations to sprite animations, and anything else that can be converted to a grid of
pixel data.

This makes heavy use of ANSI escape code sequences and the unicode UPPER HALF BLOCK character (▀)
to get 2 colors per character, meaning we get 2x the number of pixel rows compared to the number
of lines used in the terminal. While this might seem excessive and perhaps a bit silly, ... well
I can't really argue with that, it is. But this technique has a few interesting capabilities,
such as:

- This is just a stream of plain text (with embedded ANSI sequences), which means:
    - It can be treated just like any other stream of characters, which means:
        - It can be saved to a file (using shell redirection)
        - It can be piped to another process
        - It can be run over an ssh connection
- Because the "drawing" is just the terminal interpreting all the ANSI sequences, this means:
    - The entire animation, meaning all the frames, is contained within the output
        - remember, we are not mutating the screen information
        - we are just printing a very long stream of ANSI sequences
            - which causes the terminal to paint our pixels
                - and provide the illusion of mutating the screen
        - CAVEAT:
            - The timing of the animation will not be contained in the output
                - that is handled with the timers in ELO
    - So if we redirect the output stream to another terminal display
        - the animation then "plays" in that terminal
            - see the `Cool Tricks` below for more detailed examples
    - And if we save the animation to a file, we can:
        - effectively "replay" the animation using the `cat` tool
            - NOTE: as mentioned above, no timing info is retained
                - This means `cat` will "play" the animation as fast as it can print to the screen
                    - which is pretty fast :)
        - and it is just text, so anything we can with text we can do to the animation
            - see the `Cool Tricks` below for more detailed examples


*Cool Tricks*

In this snippet below we run the shader at 60 fps on a 60h x 120w pixel screen for 10 seconds.

`perl -Ilib examples/display/shader.pl 60 60 120 10`

The first thing you might notice, based on your computer of course, is that it is almost certainly
not running at 60fps. On my laptop it tends to run around 30fps. This is due to all sorts of factors,
but one is almost certainly Perl I/O buffering to the terminal.

So we could fix this in any number of ways, but this is Perl, and we should lean into our strengths
and go back to our roots in the shell. Since the animation is just a stream of text (as explained above)
we can just pipe it in the shell to `cat` like so:

`perl -Ilib examples/display/shader.pl 60 60 120 10 | cat`

You might notice, again depending on your computer, that it is running faster (or at least appears to be
based on the "fps" displayed in the output). On my laptop it manages a bit more, around 40-45fps. My
assumption here is that, from perl's point of view, writing the animation stream to a pipe is faster
than writing data to a terminal device, and this is because ... "buffering" :)

The result of this is that perl can output the animation stream faster and so from the ELO timing side,
it appears to acheive a higher fps.

To me, the overall animation appears smoother, which could be a number of things:

1. The `cat` tool is printing to the screen in very large chunks, whereas `perl` is printing much smaller chucks
2. Higher FPS will always result in a smoother animation
    - This is especially true because our animation uses the current `time` as one of it's seeds
    - Which means long render times result in a choppier animation
3. My FPS calculations are total garbage, and so it is just nonsense
    - This is a possibility, but I think I did okay with that bit, who knows.

So, this is great, we managed to get an additional 10-15fps, but we actually do better than that. As mentioned above, we can use shell redirection to send the animation stream to a file. And since it is just a text file we can read it like any other file.

For this trick, it is just easier if you create the log file first. So just make a `shader.log` file somewhere you can easily access it. Then open one terminal and run the following command:

`tail -f shader.log`

Now open another terminal and run the example, redirection the output to the log file, like so:

`perl -Ilib examples/display/shader.pl 60 60 120 10 > shader.log`

As soon as the example starts running, you should see the animation playing in the first terminal. This is basically just `tail` just following the file, which results in it interpretting the animation stream.

On my computer, this gets very close to the full 60 fps we are looking for. I believe, again, that this is due to I/O "buffering". Just as with the `cat` example above, from perl's point of view, the I/O to the pipe happened faster than the I/O to the terminal. It is my assumption that, again from perl's point of view, the I/O to the file is even faster than the I/O to the pipe. This is likely all down to the OS, file descriptors, polling, etc. etc. etc. Basically, ... "buffering".

It is also possible that `tail` is a bit faster because it is running in a completely different shell from the instance from `perl`. Whereas with the `cat` example the shell might have some management overhead to juggle both `perl` and `cat`, with `tail` that is all handled at the OS layer via the file I/O.

So anyway, now that we have the contents of our animation in a file, we can also do some cool stuff with that.

We can again use `cat` to play the animation by simply doing:

`cat shader.log`

The animation will go as fast as possible in this case, held back only by the speed of your computer, the terminal emulator and `cat`.

Since we choose a canvas that is 60 lines, and we pack 2 pixel rows per line, we can actually see the first frame of the animation using `head`, like so:

`head -30 shader.log`

You can also replay just the first few seconds of the animation like so:

`head -3000 shader.log`

And of course you can use `tail` again here to play the last few seconds of the animation, like so:

`tail -3000 shader.log`

And if you want to get really crazy, you can reverse the lines and ... well just run it and see.

`cat temp.log | perl -e 'print reverse <>'`

> NOTE: This stuff can get dicey because it is easy to hit a ANSI sequence causes your terminal to go all wonky. You've been warned :)















