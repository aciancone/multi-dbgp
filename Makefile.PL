use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => 'MultiDbgp::Debugger',
    VERSION         => '0.01',
    AUTHOR          => 'Andrea Ciancone',
    EXE_FILES       => [ qw(bin/dbgp-once_at_the_time.pl) ],
);
