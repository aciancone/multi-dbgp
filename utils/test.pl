use strict;
use warnings;

my $j='';
for my $i ( 1..10 ) {
	print "$i\n";
	$j.="$i";
	sleep 5;
}
print "$j\n";
