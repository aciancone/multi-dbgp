#!/usr/bin/perl
use strict;
use warnings;

my ( $delay, $to_print ) = @ARGV;
sleep( $delay // 0 );

my $j;
for my $i ( 1..10 ) {
	$j+=$i;
}

print "$to_print" if $to_print;
