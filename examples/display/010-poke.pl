#!perl

use v5.36;
use experimental 'try', 'builtin', 'for_list';
use builtin 'floor', 'ceil';

use Time::HiRes qw[ sleep ];

use Data::Dumper;

use ELO::Loop;
use ELO::Types  qw[ :core :events :types :typeclasses ];
use ELO::Timers qw[ :timers :tickers ];

use ELO::Graphics;

# ...

# https://htmlcolors.com/palette/70/super-mario-bros

my $EMPTY  = TransPixel();
my $RED    = ColorPixel( Color( 0.8, 0.2, 0.2 ) );
my $BLACK  = ColorPixel( Color( 0.0, 0.0, 0.0 ) );
my $BLUE   = ColorPixel( Color( 0.0, 0.3, 0.6 ) );
my $GOLD   = ColorPixel( Color( 0.8, 0.6, 0.4 ) );
my $BROWN  = ColorPixel( Color( 0.5, 0.3, 0.3 ) );
my $WHITE  = ColorPixel( Color( 1.0, 1.0, 1.0 ) );
my $YELLOW = CharPixel( Color( 1.0, 1.0, 0.0 ), Color( 0.7, 0.6, 0.0 ), '*' );

my $mario_palette = Palette({
    '$' => $RED,
    ' ' => $EMPTY,
    '`' => $BLACK,
    '.' => $BROWN,
    ':' => $BLUE,
    '@' => $GOLD,
    '#' => $WHITE,
    '%' => $YELLOW,
});

# ...

my $small_mario_image_data = ImageData( $mario_palette, [
'   $$$$$    ',
'  $$$$$$$$$ ',
'  ...@@`@   ',
' .@.@@@`@@@ ',
' .@..@@@.@@ ',
' ..@@@@@... ',
'   @@@@@@@  ',
'  ::$::$::  ',
' :::$::$::: ',
':::$$$$$$:::',
'## $%$$%$ ##',
'@@@$$$$$$@@@',
'@@$$$$$$$$@@',
'  $$$  $$$  ',
' ...    ... ',
'....    ....',
]);

my $big_mario_image_data = ImageData( $mario_palette, [
    ' ###                 ',
     '####   $$$$$$$$      ',
     '###$$$$$$$$$$$$$     ',
     '###$$$$$$$$$$$$$     ',
     ':::   @@`@@@...      ',
     ':::  @@@`@@@@.@.     ',
     ':::::@@@`@@@..@.     ',
     '::@@@@..@@@@....     ',
     '  .......@@@@@..     ',
     '   ::@@@@@@@@@       ',
     '     :$$::::$$:::::  ',
     '     :$$::::$$:::::: ',
     '     :$$::::$$:::::: ',
     '     ::::::$:::: ### ',
     ' ```  :$$$$$:::: ####',
     ' ``  %%$$$%%$:$$ ####',
     ' ``$$%%$$$%%$$$$  ## ',
     ' ``$$$$$$$$$$$$``    ',
     ' ``$$$$$$$$$$$````   ',
     '        $$$$$$$```   ',
     '           $$$  ``   ',
     '                ``   ',
]);

my $small_mario_image = $small_mario_image_data->create_image;
my $big_mario_image   = $big_mario_image_data->create_image;

#die Dumper $small_mario_image;

my $HEIGHT  = 30;
my $WIDTH   = 90;
my $DELAY   = 0.5;

my $d = Display(
    *STDOUT,
    Point(0,0)->rect_with_extent( Point($WIDTH, $HEIGHT) )
);

{
    $d->clear_screen( Color( 0, 0.7, 1.0 ) );
    sleep($DELAY);

    $d->poke( Point( $_, $_ ), $BLUE ) for 0 .. 6;
    $d->poke( Point( $_, (6 - $_) ), $RED  ) for reverse 0 .. 6;

    $d->poke_rectangle( $d->area->inset_by( Point( 8, 2 ) ), Color( 0.1, 0.7, 0.3 ) );
    sleep($DELAY);

    $d->poke_fill(
        GradientFillHGR(
            $d->area->inset_by( Point( 5, 10 ) ),
            Gradient(
                Color( 0.5, 0.3, 0.9 ),
                Color( 0.0, 1.0, 0.4 ),
                20, # 2x since it is HGR
            ),
            Vertical()
        ),
    );
    sleep($DELAY);

    $d->poke_block( Point( 5, 10 ), $small_mario_image );
    sleep($DELAY);

    $d->poke_block( Point( 20, 7 ), $small_mario_image ->flip->lighten( 0.4 ) );
    sleep($DELAY);

    $d->poke_rectangle( $d->area->inset_by( Point( 20, 14 ) ), Color( 0.3, 0.9, 0.9 ) );
    sleep($DELAY);

    $d->poke_block( Point( 35, 5 ), $small_mario_image->mirror );
    sleep($DELAY);

    $d->poke_block( Point( 50, 8 ), $small_mario_image->mirror->flip->darken ( 0.4 ) );
    sleep($DELAY);

    $d->poke_fill(
        GradientFill(
            Point( 40, 12 )->rect_with_extent( Point( 30, 2 ) ),
            Gradient(
                Color( 1.0, 0.1, 0.2 ),
                Color( 0.5, 0.5, 0.5 ),
                10,
            ),
            Horizontal()
        ),
    );
    sleep($DELAY);

    $d->poke_block( Point( 65, 11 ), $small_mario_image->flip->mirror );
    sleep($DELAY);

    $d->poke_block( Point( 30, 8 ), $big_mario_image );
    sleep($DELAY);
}

$d->end_cursor;

say "\n\n\nGoodbye";

1;

__END__

my $big_mario = ImageData(
    Palette({
    '@' => RGBA( 255, 255, 255, 0 ),
    '0' => RGBA( 250, 250, 250, 1 ),
    'G' => RGBA( 240, 240, 240, 1 ),
    'C' => RGBA( 220, 220, 220, 1 ),
    '8' => RGBA( 200, 200, 200, 1 ),
    'L' => RGBA( 180, 180, 180, 1 ),
    'f' => RGBA( 160, 160, 160, 1 ),
    't' => RGBA( 140, 140, 140, 1 ),
    '1' => RGBA( 120, 120, 120, 1 ),
    'i' => RGBA( 100, 100, 100, 1 ),
    ';' => RGBA(  80,  80,  80, 1 ),
    ':' => RGBA(  60,  60,  60, 1 ),
    ',' => RGBA(  40,  40,  40, 1 ),
    '.' => RGBA(  20,  20,  20, 1 ),
    ' ' => RGBA(   0,   0,   0, 1 ),
}),
[
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@0GLft11ii1tfLG08@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@0Ct1iiiiiitCCLCCLtLC0@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@@@@@@@@@@8Gf1iiiiiiiif88Gi1f1itfff0@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@@@@@@@@@GtiiiiiiiiiiiL88L;tCtfL1ttiL8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@@@@@@@0f1iiii11iiiiii1C0LitGGGCLiii;1fffLCG0@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@@@@@@C1iiii1111iiiiiiiitLLLLft1i;;;::::::::;1C@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@@@@8L1iii11111iiiiiiiiiii1i;;:::::::::::::::::f8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@@@8Liiii11111iiiiiiiiiii;;::::::::::::::::::::;C@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@@@Liiii11111iiiiiiiiii;:::::;;;::::::::::::::::L8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@@Ciiii11111iiiiiiii;;:,:;;ii11111ii:,,,,,,,,,:1C@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@01iiii111iiiiiiii;;:......,;1ttttt1, ..,,,,,:1C8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@fiiiiiiiiiiiiiii;;i, .:;;;;::1fffft:i1;,,,:ifG8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@Giiiiiiiiiiiii;;;i11:;1ffffffttLfffffLLf1:1LG8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@8fiiiiiiii;;;;;i11ttftfffLLLCCCLLLLLLf1tLLLG08888@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@0fiiiiiii;;;;:itfCCGGGGGGCGLffC00CGGGCLfC00000GGGGG08@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@8fiiiiiiii;;;;:,iG00000000GGL;1:iC00000G00888000GGGCCCC0@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@fiiiiiiii;;;:::::fG00000000GL::,,tG0G0000888000GGGCCCLLC@@@8@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@81iiiiii;;;;:::::::itG008000GGt;::tG0G0G000000GGGCCCLLLLC0GCCG0888808888@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@8tiii1fLLLf1;::::::::i08880Gi;iii1tLLLLLCGGGGGGCCLLLLLLLffffLG888008880008@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@0tifG0GGGGGCt;:::::iL08888G:.,,,.......;1fLLLLLLLLff1fttfftf088GC8080G0880G08@@@@@@@@@@@',
'@@@@@@@@@@@@@8C0GCCGCCLLGLi::::L8888888C;,........  .,:;;iii;:,.,f11tti1LGGL0880G8080GCCC8@@@@@@@@@@',
'@@@@@@@@@@@@@@80GGGGLLLLLGGf;:iG888888880Cft1i,.   ..     ..  :;tGfi11i1tfffG00C088GCLLCCG@@@@@@@@@@',
'@@@@@@@@@@@@@@@0GG0GCCGGGG00GCG000000000000GGGL1::itt;:,:;iiiittLfi11tttfttifCCfCGGCLfLCCG@@@@@@@@@@',
'@@@@@@@@@@@@@@@80000GGG000000000000000000GGGGCCL;;iii;:,,,1ftttLGtii1ttffft11LLLfLLLLLLCCG@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@8000000000GGGG0000GGGGGGGGGCCCC1......,.;fftfLG@0ti11ttttttfCGGGGCLLLCCCG@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@@80GGGGGCti;iLCGGGGGGCCCCCCCCCCCt;:::;;iffffC0@@@8Cf11111ttfLCGGCCLLLCCLG@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@@@@@80GGt::,,:ifffffffLLLLLLLLCCGCLfttffffLG8@@@@@@@0fii11tttfLLLLLLLLLLC8@@@@@@@@@',
'@@@@@@@@@@@@@@@@@8GCfft11iiiii;;;iiiiiii111tfffLCCCCCLLftttfCGG00888@@01;ii11fLLLLLLffLLCC8@@@@@@@@@',
'@@@@@@@@@@@@@@8Gf1iiiiiiiiiiiiii;;;;;;;iiiiii11ttfffft1i:,,,:::::;;i11ti:;i1LCGGGCCLLffCG8@@@@@@@@@@',
'@@@@@@@@@@@@@Gtiiiiiiiiiiiiiii;;;;;;;;;;iiiiiiii;;;;:::,,,,,,,,,,,,,,,,,,,,:;iiiiii;;;iC@@@@@@@@@@@@',
'@@@@@@@@@@@0fiiiiiiiiiiiii;;;;;;;;;;;;;;;iiii11i1iii;;;;::::::::::::,,,,,,,,:;;;;::::;f0@@@@@@@@@@@@',
'@@@@@@@@@@C1iiiiiiiiii;;;;;;;;;;;;;;;;;;;;;i11tfffft1iiiiiii;;;;;1ffi:,,,,,,:::;;;:::1C@@@@@@@@@@@@@',
'@@@@@@@@8Liiiiiiiiii;;;;;;;;:::::;;;;;;;;;;i11LLLLLLtiiiiiiiii;;;;itft:,,,,,::::::::iL8@@@@@@@@@@@@@',
'@@@@@80Ctiiiiiiiii;;;;:::::::::::::::::;;;i111fLLLft1ii;iiiiii;;;;;;i1;,,,,::::::::iL0@@@@@@@@@@@@@@',
'@@@@88Gfiiiiiiiii;;;;::::i1ttti:::::::;;;i1111111111i;:;iiiiii;;;;;;::::::::::::;itC0@@@@@@@@@@@@@@@',
'@@@@8880f1iiiii;;;;::::ifG8@@@L;;::::;;i111111iiiii;;:;iiiiiii;;;;;;;::iftttttfLCG8@@@@@@@@@@@@@@@@@',
'@@@888008GLtii;;;:::::tC8@@@@@0i;;;;;i1111111111iiiiiiiiiiiii;;;;;;;;;;;L8@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@888888880CLt1ii;;;if8@@@@@@@C1iiii111111111111iiiiiiiiiiiiiiii;;;;:::;C@@@@@@@@@8888@@@@@@@@@@@@@',
'@@80008888000GGCLLft1tL0@@@@@@@@C1iii111111111111iiiii11111111111iii;;:::t8@@@8GCLftttttfLC0@@@@@@@@',
'@88000088880GCLLfftt1tG@@@@@@@@@8fii1i111111111iii1111111111111111iiiii;;iG@8Cfttttt111ii;;i1L0@@@@@',
'88800008888800GCftt111L@@@@@@@@@@Gi1i1i111111iii11111111111111111111iiiiii1Lftfffffttt11i;;;::;f8@@@',
'888880088888000GCLftt1tG@@@@@@@@@Gi1iii11111i11111111111111111111111111iiii1tffffffft11i;;;;;;;:i0@@',
'888880888880000GCLfttt1L8@@@@@@@@Liii1i111111111111111111111111111111111111ttfffLfft1i;i1t11111iit8@',
'@808888888800GGCLLfffttL0@@@@@@@8tiiiii111111111111111111111111111111111111ttfffffti;itt1111111111L8',
'@@8800888000GCLLLfLLLffC8@@@@@@@81iiiiii11111111111iiiiiiii1111111111111111tttfffti;tft11111111111tG',
'@@@@0GG000GCLLffttfLLLC0@@@@@@@@8tiiiiii1111111iiiiiiiiiiiii1111111111111111ttttti;tf11111tttt1111tC',
'@@@@@800GCCLfftffLGGG08@@@@@@@@@@Liiiiiii1111iiiiiiiiiiiiiiiiii11111111i11111111i;tf1111tttttt1111fG',
'@@@@@@@@80CLLfLLC0@@@@@@@@@@@@@@@8tiiiiiiiiiiiiiiiiiiii;iiiiiiii111111ii1111111i;1f11111tttttt111tC8',
'@@@@@@@@@@80G008@@@@@@@80CffftttfCC1iiiiiiiiiiiiiiiiiii;;;;iiiiiiii111i1111111i;if111111tttt1111tC0@',
'@@@@@@@@@@@@@@@@@@@@@8Gf1iiiii;;;;iiiiiiiiiiiiiiiiiii;;;;;;;;iiiiiiiiii11111ii;;tt1111111111111fC8@@',
'@@@@@@@@@@@@@@@@@@@@8Ct11tt1iiiiiiiii;;;;ii;;;;;;;;;;;;;;;;;;;iiiiiiiii111iii;:11111111111111fC08@@@',
'@@@@@@@@@@@@@@@@@@@@Cf11fft1iiiiiiiiii:::::;;;;;;;;;;;;;:::::;fCfiiii;iiiiii;:;i;;;;;;;;;;ifC0@@@@@@',
'@@@@@@@@@@@@@@@@@@@8f11tft1iii1iiiiiii;:::::::::::::::::::::;fG@@0fii;iiiii;:i1i;;;;;;;;;;iC8@@@@@@@',
'@@@@@@@@@@@@@@@@@@@0f11ff1iiiiiiiiiiii;::::::::::::::::::::ifG@@@@@Ci;;iii;:;t111111111111fG8@@@@@@@',
'@@@@@@@@@@@@@@@@@@@8f1tftiiiiiiiiiiiiii;::::::::::::::::;;1L0@@@@@@@G1i;;;::1t111tttt111tfG8@@@@@@@@',
'@@@@@@@@@@@@@@@@@8Gt1ttftiiiiiiiiiiiiii;;::::::::::::::;itC8@@@@@@@@@80Li;::t1111ttt111fC0@@@@@@@@@@',
'@@@@@@@@@@@@@@@@8L11tffftiiiiiiii;;;;;;;;::::::::::::;itC0@@@@@@@@@@@@@@8L1;i1111111tfC08@@@@@@@@@@@',
'@@@@@@@@@@@@@@@8L11tfffftiiii;;;;;;;;;::::::::::::;i1fC08@@@@@@@@@@@@@@@@@@0GCLfffLC08@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@Cti1tffLfti;;;;;;;:::::::::::;;i1tfCG08@@@@@@@@@@@@@@@@@@@@@@@@@@8@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@8f1ittfffft1;;;;;::::::;i1tfLCCG088@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@8fii1ttffft1i;::::::::;L088@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@Gii1ttttt1ii;::::::::tG@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@Cii111111i;;::::::;1C8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@C1iiiiii;;;:::::;tG8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@@8Ct1i;;;;;;;;itC0@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
'@@@@@@@@@@@@@@@@@@@@@0GLftttfLCG8@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
]);

my $big_mario_image = $big_mario->create_image;

$display->turn_on;

$display->poke_block( 5, 5, $big_mario_image );


my $big_mario = ImageData(
    Palette({
    '@' => RGBA( 255, 255, 255, 0 ),
    '0' => RGBA( 250, 250, 250, 1 ),
    'G' => RGBA( 240, 240, 240, 1 ),
    'C' => RGBA( 220, 220, 220, 1 ),
    '8' => RGBA( 200, 200, 200, 1 ),
    'L' => RGBA( 180, 180, 180, 1 ),
    'f' => RGBA( 160, 160, 160, 1 ),
    't' => RGBA( 140, 140, 140, 1 ),
    '1' => RGBA( 120, 120, 120, 1 ),
    'i' => RGBA( 100, 100, 100, 1 ),
    ';' => RGBA(  80,  80,  80, 1 ),
    ':' => RGBA(  60,  60,  60, 1 ),
    ',' => RGBA(  40,  40,  40, 1 ),
    '.' => RGBA(  20,  20,  20, 1 ),
    ' ' => RGBA(   0,   0,   0, 1 ),
}),
[
'                                ,:i1tffLLft1i:,.                                                     ',
'                             ,;tfLLLLLLt;;i;;iti;,                                                   ',
'                          .:1fLLLLLLLL1..:Lf1fLt111,                                                 ',
'                         :tLLLLLLLLLLLi..iCt;t1ifttLi.                                               ',
'                       ,1fLLLLffLLLLLLf;,iLt:::;iLLLCf111i;:,                                        ',
'                      ;fLLLLffffLLLLLLLLtiiii1tfLCCCGGGGGGGGCf;                                      ',
'                    .ifLLLfffffLLLLLLLLLLLfLCCGGGGGGGGGGGGGGGGG1.                                    ',
'                   .iLLLLfffffLLLLLLLLLLLCCGGGGGGGGGGGGGGGGGGGGC;                                    ',
'                   iLLLLfffffLLLLLLLLLLCGGGGGCCCGGGGGGGGGGGGGGGGi.                                   ',
'                  ;LLLLfffffLLLLLLLLCCG0GCCLLfffffLLG000000000Gf;                                    ',
'                 ,fLLLLfffLLLLLLLLCCG8888880Cftttttf0@8800000Gf;.                                    ',
'                 1LLLLLLLLLLLLLLLCCL0@8GCCCCGGf1111tGLfC000GL1:.                                     ',
'                :LLLLLLLLLLLLLCCCLffGCf111111tti11111ii1fGfi:.                                       ',
'               .1LLLLLLLLCCCCCLfftt1t111iii;;;iiiiii1ftiii:,....                                     ',
'              ,1LLLLLLLCCCCGLt1;;::::::;:i11;,,;:::;i1;,,,,,:::::,.                                  ',
'            .1LLLLLLLLCCCCG0L:,,,,,,,,::iCfGL;,,,,,:,,...,,,:::;;;;,                                 ',
'            1LLLLLLLLCCCGGGGG1:,,,,,,,,:iGG00t:,:,,,,...,,,:::;;;ii;   .                             ',
'           .fLLLLLLCCCCGGGGGGGLt:,,.,,,::tCGGt:,:,:,,,,,,:::;;;iiii;,:;;:,....,....                  ',
'           .tLLLf1iii1fCGGGGGGGGL,...,:LCLLLftiiiii;::::::;;iiiiiii1111i:...,,...,,,.                ',
'            ,tL1:,:::::;tCGGGGGLi,....:G80008888888Cf1iiiiiiii11f1tt11t1,..:;. .,:,..,:,.            ',
'             .;,:;;:;;ii:iLGGGGi.......;C088888888@@80GCCLLLCG0801ffttLfi::i,..,:. .,:;;;.           ',
'              .,::::iiiii::1CGL:........,;1tfL08@@@88@@@@@88@@GCt:1LffLft111:,,;,..:;ii;;:           ',
'               ,::,:;;::::,,:;:,,,,,,,,,,,,:::ifGGLttCG0GCLLLLtti1Lffttt1ttL1;;1;::;i1i;;:           ',
'               .,,,,:::,,,,,,,,,,,,,,,,,,::::;;iCCLLLCG000f1ttti:tLLftt111tffiii1iiiiii;;:           ',
'                 .,,,,,,,,,::::,,,,:::::::::;;;;f88888808C11t1i: ,tLfftttttt1;::::;iii;;;:           ',
'                  .,:::::;tLCLi;::::::;;;;;;;;;;;tCGGGCCL1111;,   .;1ffffftt1i;::;;iii;;i:           ',
'                     .,::tGG00GL1111111iiiiiiii;;:;i1tt1111i:.       ,1LLffttt1iiiiiiiiii;.          ',
'                 .:;11tffLLLLLCCCLLLLLLLffft111i;;;;;ii1ttt1;::,,...  ,fCLLff1iiiiii11ii;;.          ',
'              .:1fLLLLLLLLLLLLLLCCCCCCCLLLLLLfftt1111tfLG000GGGGGCCLfftLGCLfi;:::;;ii11;:.           ',
'             :tLLLLLLLLLLLLLLLCCCCCCCCCCLLLLLLLLCCCCGGG00000000000000000000GCLLLLLLCCCL;             ',
'           ,1LLLLLLLLLLLLLCCCCCCCCCCCCCCCLLLLffLfLLLCCCCGGGGGGGGGGGG00000000GCCCCGGGGC1,             ',
'          ;fLLLLLLLLLLCCCCCCCCCCCCCCCCCCCCCLfft1111tfLLLLLLLCCCCCf11LG000000GGGCCCGGGf;              ',
'        .iLLLLLLLLLLCCCCCCCCGGGGGCCCCCCCCCCLffiiiiiitLLLLLLLLLCCCCLt1tG00000GGGGGGGGLi.              ',
'     .,;tLLLLLLLLLCCCCGGGGGGGGGGGGGGGGGCCCLfff1iii1tfLLCLLLLLLCCCCCCLfC0000GGGGGGGGLi,               ',
'    ..:1LLLLLLLLLCCCCGGGGLftttLGGGGGGGCCCLffffffffffLCGCLLLLLLCCCCCCGGGGGGGGGGGGCLt;,                ',
'    ...,1fLLLLLCCCCGGGGL1:.   iCCGGGGCCLffffffLLLLLCCGCLLLLLLLCCCCCCCGGL1ttttt1i;:.                  ',
'   ...  .:itLLCCCGGGGGt;.     ,LCCCCCLffffffffffLLLLLLLLLLLLLCCCCCCCCCCCi.                           ',
'   ........,;itfLLCCCL1.       ;fLLLLffffffffffffLLLLLLLLLLLLLLLLCCCCGGGC;         ....              ',
'  .   ....,,,::;ii1tfti,        ;fLLLffffffffffffLLLLLfffffffffffLLLCCGGGt.   .:;i1ttttt1i;,         ',
' ..    ....,:;ii11ttft:         .1LLfLfffffffffLLLffffffffffffffffLLLLLCCL: .;1tttttfffLLCCLfi,      ',
'...    .....,,:;1ttfffi          :LfLfLffffffLLLffffffffffffffffffffLLLLLLfi1t11111tttffLCCCGGC1.    ',
'.....  .....,,,:;i1ttft:         :LfLLLfffffLffffffffffffffffffffffffffLLLLft1111111tffLCCCCCCCGL,   ',
'..... .....,,,,:;i1tttfi.        iLLLfLfffffffffffffffffffffffffffffffffffftt111i11tfLCLftfffffLLt.  ',
' .,........,,::;ii111tti,       .tLLLLLfffffffffffffffffffffffffffffffffffftt11111tLCLttffffffffffi. ',
'  ..,,...,,,:;iii1iii11;.       .fLLLLLLfffffffffffLLLLLLLLffffffffffffffffttt111tLCt1tffffffffffft: ',
'    ,::,,,:;ii11tt1iii;,        .tLLLLLLfffffffLLLLLLLLLLLLLfffffffffffffffftttttLCt1fffffttttfffft; ',
'     .,,:;;i11t11i:::,.          iLLLLLLLffffLLLLLLLLLLLLLLLLLLffffffffLffffffffLCt1ffffttttttffff1: ',
'        .,;ii1ii;,               .tLLLLLLLLLLLLLLLLLLLLCLLLLLLLLffffffLLfffffffLCf1fffffttttttffft;. ',
'          .,:,,.       .,;111ttt1;;fLLLLLLLLLLLLLLLLLLLCCCCLLLLLLLLfffLfffffffLCL1ffffffttttfffft;,  ',
'                     .:1fLLLLLCCCCLLLLLLLLLLLLLLLLLLLCCCCCCCCLLLLLLLLLLfffffLLCCttfffffffffffff1;.   ',
'                    .;tffttfLLLLLLLLLCCCCLLCCCCCCCCCCCCCCCCCCCLLLLLLLLLfffLLLCGffffffffffffff1;,.    ',
'                    ;1ff11tfLLLLLLLLLLGGGGGCCCCCCCCCCCCCGGGGGC1;1LLLLCLLLLLLCGCLCCCCCCCCCCL1;,       ',
'                   .1fft1tfLLLfLLLLLLLCGGGGGGGGGGGGGGGGGGGGGC1:  ,1LLCLLLLLCGLfLCCCCCCCCCCL;.        ',
'                   ,1ff11fLLLLLLLLLLLLCGGGGGGGGGGGGGGGGGGGGL1:     ;LCCLLLCGCtffffffffffff1:.        ',
'                   .1ft1tLLLLLLLLLLLLLLCGGGGGGGGGGGGGGGGCCfi,       :fLCCCGGftfffttttffft1:.         ',
'                 .:tftt1tLLLLLLLLLLLLLLCCGGGGGGGGGGGGGGCLt;.         .,iLCGGtfffftttfff1;,           ',
'                .ifft111tLLLLLLLLCCCCCCCCGGGGGGGGGGGGCLt;,              .ifCLffffffft1;,.            ',
'               .ifft1111tLLLLCCCCCCCCCGGGGGGGGGGGGCLf1;,.                  ,:;i111i;,.               ',
'               ;tLft11i1tLCCCCCCCGGGGGGGGGGGCCLft1;:,.                          .                    ',
'              .1fLtt1111tfCCCCCGGGGGGCLft1i;;:,..                                                    ',
'              .1LLftt111tfLCGGGGGGGGCi,..                                                            ',
'               :LLftttttfLLCGGGGGGGGt:                                                               ',
'                ;LLffffffLCCGGGGGGCf;.                                                               ',
'                 ;fLLLLLLCCCGGGGGCt:.                                                                ',
'                  .;tfLCCCCCCCCLt;,                                                                  ',
'                     ,:i1ttt1i;:.                                                                    ',
]);

my $big_mario_image = $big_mario->create_image;

$display->turn_on;

$display->poke_block( 5, 5, $big_mario_image );

