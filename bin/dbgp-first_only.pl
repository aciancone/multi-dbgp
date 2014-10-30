use strict;
use warnings;

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Tools qw(mutex);

use MultiDbgp::Debugger;

use Data::Dumper;

my $cv = AE::cv;

my $first_debugger;
my $mutex = mutex;

sub set_first_dbgp_debugger {
	my ( $debugger ) = @_;

	my $is_first_dbgp_debugger = 0;
        $mutex->lock( sub {
        	my ($mutex_guard) = @_;

		if( !defined $first_debugger ) {
			$first_debugger = $debugger;
			$is_first_dbgp_debugger = 1;
		}

                undef $mutex_guard; # unlock mutex
        });
	return $is_first_dbgp_debugger;
}

sub unset_first_dbgp_debugger {
	my ( $debugger ) = @_;

        $mutex->lock( sub {
        	my ($mutex_guard) = @_;

		if( $first_debugger = $debugger ) {
			undef $first_debugger;
		}

                undef $mutex_guard; # unlock mutex
        });
}

print STDERR "Starting DBGp dispatcher\n";

my $client;

tcp_server( undef, 9001, sub {
      	my $debugger_fh = shift;

	print STDERR "New DBGp incoming connection\n";

	my $debugger = new MultiDbgp::Debugger( $debugger_fh );
	if( !$debugger ) {
		print STDERR "Debugger: $!\n";
		return -1;
	}

	if( set_first_dbgp_debugger($debugger) ) {
		print "First debugger connected\n";
		tcp_connect( "localhost", 9000, sub {
			print "Connected to client\n";
			my $client_fh = shift;
		
			if( !$client_fh ) {
				print STDERR "Client: $!\n";
				$debugger->command_detach();
				unset_first_dbgp_debugger( $debugger_fh );
				return -1;
			}

			$client = AnyEvent::Handle->new(
				fh => $client_fh,
				on_eof => sub {
					print "Client eof\n";
					$debugger->command_detach();
					unset_first_dbgp_debugger( $debugger_fh );
				},
				on_error => sub {
					print "Client error:\n";
					print STDERR Data::Dumper::Dumper @_;
					$debugger->command_detach();
					unset_first_dbgp_debugger( $debugger_fh );
				},
			);
			$debugger->bind_to_client( $client );
		});
	}
	else {
		print "Another debugger connected\n";
		$debugger->command_detach();
	}

});

$cv->recv;
