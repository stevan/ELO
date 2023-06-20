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

my $big_mario = ImageData(
    Palette({
    '@' => TransPixel(),
    '0' => ColorPixel( Color( 0.90, 0.90, 0.90 ) ),
    'G' => ColorPixel( Color( 0.80, 0.80, 0.80 ) ),
    'C' => ColorPixel( Color( 0.75, 0.75, 0.75 ) ),
    '8' => ColorPixel( Color( 0.70, 0.70, 0.70 ) ),
    'L' => ColorPixel( Color( 0.65, 0.65, 0.65 ) ),
    'f' => ColorPixel( Color( 0.60, 0.60, 0.60 ) ),
    't' => ColorPixel( Color( 0.55, 0.55, 0.55 ) ),
    '1' => ColorPixel( Color( 0.50, 0.50, 0.50 ) ),
    'i' => ColorPixel( Color( 0.45, 0.45, 0.45 ) ),
    ';' => ColorPixel( Color( 0.40, 0.40, 0.40 ) ),
    ':' => ColorPixel( Color( 0.30, 0.30, 0.30 ) ),
    ',' => ColorPixel( Color( 0.20, 0.20, 0.20 ) ),
    '.' => ColorPixel( Color( 0.10, 0.10, 0.10 ) ),
    ' ' => ColorPixel( Color( 0.00, 0.00, 0.00 ) ),
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
'@@@@@@@@@@@@fiiiiiiii;;;:::::fG00000000GL::,,tG0G0000888000GGGCCCLLC@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
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

# ...

my $HEIGHT  = 67;
my $WIDTH   = 103;

my $d = Display(
    *STDOUT,
    Point(0,0)->rect_with_extent( Point($WIDTH, $HEIGHT) )
);

$d->clear_screen( Color( 0, 0.7, 1.0 ) );

$d->poke_block( Point( 2, 1 ), $big_mario_image );

$d->end_cursor;

say "\n\n\nGoodbye";

1;

__END__

