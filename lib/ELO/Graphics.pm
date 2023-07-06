package ELO::Graphics;
use v5.36;

$|++;

use ELO::Graphics::Colors;
use ELO::Graphics::Geometry;
use ELO::Graphics::Pixels;
use ELO::Graphics::Images;
use ELO::Graphics::Fills;
use ELO::Graphics::Shaders;
use ELO::Graphics::Scrollers;
use ELO::Graphics::Displays;

## ----------------------------------------------------------------------------
## Exportables
## ----------------------------------------------------------------------------

use Exporter 'import';

our @EXPORT = (
      @ELO::Graphics::Colors::EXPORT,
    @ELO::Graphics::Geometry::EXPORT,
      @ELO::Graphics::Pixels::EXPORT,
      @ELO::Graphics::Images::EXPORT,
       @ELO::Graphics::Fills::EXPORT,
     @ELO::Graphics::Shaders::EXPORT,
   @ELO::Graphics::Scrollers::EXPORT,
    @ELO::Graphics::Displays::EXPORT,
);


# TODO:
# - BitMasks (over images, gradients?, shaders?)
# - Sprite (image + bg-color)

1;

__END__



=pod

https://iterm2.com/documentation-escape-codes.html
https://vt100.net/docs/vt510-rm/IRM.html ???

https://metacpan.org/pod/Chart::Colors << return an endless stream of new distinct
                                          RGB colours codes (good for coloring any
                                          number of chart lines)

TODO:

Use smalltalk as inspiration

http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/EoC.htm

http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/DisplScreen.htm
    http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Form.htm
        http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/DisplayMedium.htm
            http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/DisplayObject.htm


http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/Pen.htm
http://www.bildungsgueter.de/Smalltalk/Pages/MVCTutorial/Pages/BitBlt.htm

=cut
