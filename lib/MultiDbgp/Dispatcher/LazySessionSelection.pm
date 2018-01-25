package MultiDbgp::Dispatcher::LazySessionSelection;
use strict;
use warnings;

use AnyEvent::Handle;
use AnyEvent::Socket;
use Scalar::Util qw(refaddr);

sub new {
	my ( $class, $configuration ) = @_;

	return bless {
		configuration	=> $configuration,
	 }, $class;
}

sub new_client {
	my ( $self, $client ) = @_;

	die "Dispatcher: undesidered new client. state: ".$self->{ state } if $self->{ client } || $self->{ state } ne "waiting_client";

	$client->add_on_command_handler( \&on_client_new_command_handler, $self );
	$client->add_on_error_or_exit_handler( \&client_error_or_exit, $self );
	$self->{ client } = $client;
}

sub new_debugger {
	my ( $self, $debugger, $init_message ) = @_;

	print STDERR "add debugger into the pool\n";

	$debugger->add_on_message_handler( \&detect_debugger_in_break_status, $self );

	if( ! @{ $self->{ debuggers } } ) {
		$self->{ forwarded_debugger } = $debugger;
		$self->forward_message_to_client( $debugger, $init_message );
		$debugger->add_on_message_handler( \&forward_message_to_client, $self );
	}

	$self->align_new_debugger_state( $debugger );
	# it is ready to receive live command
	push @{ $self->{ debuggers } }, $debugger;
}

sub detect_debugger_in_break_status {
	my ( $self, $debugger, $message, $related_command ) = @_;

#	print STDERR " -- BREAK STATUS " . $message->is_debugger_in_break_status() ."\n";
	return if( ! $message->is_debugger_in_break_status() );

	print STDERR "Client start session with " . $debugger->get_app_id() ."\n";
	$self->{ state } = 'session';

	for my $dbg ( @{ $self->{ debuggers } } ) {
		$dbg->del_on_message_handlers( );
		
		$dbg->command_detach( ) if( refaddr( $debugger ) != refaddr( $dbg ) );; 
	}
	$debugger->add_on_message_handler( \&forward_message_to_client, $self );
}

sub on_client_new_command_handler {
	my ( $self, $command ) = @_;

	for my $debugger ( @{ $self->{ debuggers } } ) {
		$debugger->commands( [ $command ] ); 
	}
}

sub forward_message_to_client {
    my ( $self, $debugger, $message, $related_command ) = @_;

    # TODO detect if it is an old message due to switch of debugger

    if( $self->{ client } ) {
        $self->{ client }->send_message( $message );
    }
    else {
        $debugger->command_detach();
        $debugger->end( );

        $self->init();
    }
}

sub debugger_error_or_exit {
    my ( $self, $debugger, $reason, $fatal, $message ) = @_;

    if( $self->{ state } eq "waiting_debugger" || $self->{ state } eq "waiting_client" ) {
        my $i = 0;
        while( $i < @{ $self->{ on_new_client } } ) {
            if( refaddr( $debugger ) != refaddr( $self->{ on_new_client }[$i] ) ) {
                $i++;
            }
            else {
                delete $self->{ on_new_client }[$i];
            }
        }
        $self->{ state } = "waiting_debugger" unless @{ $self->{ on_new_client } };
        return;
    }

    my $i = 0;
    while( $i < @{ $self->{ debuggers } } ) {
        if( refaddr( $debugger ) != refaddr( $self->{ debuggers }[$i] ) ) {
            $i++;
        }
        else {
            delete $self->{ debuggers }[$i];
        }
    }

    if( refaddr( $debugger ) != refaddr( $self->{ forwarded_debugger } ) ) {
        return;
    }

    if( $self->{ state } eq 'session' ) {
        $self->{ client }->end() if $self->{ client };
        $self->init();
        return;
    }

    if( ! @{ $self->{ debuggers } } ) {
        $self->{ client }->end() if $self->{ client };
        $self->init();
        return;
    }
     
    $self->{ forwarded_debugger } = $self->{ debuggers }[0];
    $self->{ debuggers }[0]->add_on_message_handler( \&forward_message_to_client, $self );
}

sub client_error_or_exit {
	my ( $self, $message ) = @_;

	$self->detach_all_debuggers();

	$self->init();
}

sub align_new_debugger_state{
	my ( $self, $debugger ) = @_;

	$debugger->commands( $self->{ client }->get_all_precedent_commands() );
}

sub init {
	my ( $self ) = @_;

	$self->{ client } = undef;
	$self->{ debuggers } = [];
	$self->{ on_new_client } = [];
	$self->{ forwarded_debugger } = undef;

	# dispatcher states: 1. waiting_debugger, 2. waiting_client, 3. multiplexing, 4. session 
	$self->{ state } = 'waiting_debugger';
}
sub start {
	my ( $self ) = @_;

	$self->init();

	print STDERR "Starting DBGp dispatcher\n";

	my $debugger_host = $self->{ configuration }{ debugger_host };
	my $debugger_port = $self->{ configuration }{ debugger_port } // die "missing debugger_port";
	tcp_server(
		$debugger_host,
		$debugger_port,
		sub {
			my $debugger_fh = shift;

			print STDERR "New DBGp incoming connection\n";

			my $debugger = new MultiDbgp::Debugger( $debugger_fh );
			if( !$debugger ) {
				print STDERR "Debugger: $!\n";
				return -1;
			}

            $debugger->add_on_error_or_exit_handler( \&debugger_error_or_exit, $self );
			$debugger->start( sub {
				shift;
				shift;
				my $init_message = shift;

				if( $self->{ state } eq "multiplexing" ) {
					die "where is the client" if( ! $self->{ client } );
					$self->new_debugger( $debugger, $init_message );
					return;
				}

				if( $self->{ state } eq 'session' ) {
					print STDERR "Client busy in a session\n";
					$debugger->command_detach();
					return;
				}

				$self->get_debugger_client( sub {
					my ( $error, $client ) = @_;

					if( $error ) {
						print STDERR "Client: $error\n";
						$debugger->command_detach();
						$self->detach_all_debuggers();
						return;
					}

					return $debugger->command_detach() if( $self->{ state } ne "multiplexing" );

					$self->new_debugger( $debugger, $init_message );

				});
			} );
		}
	);
    if( $debugger_host eq 'unix/' ) {
        chmod( 0777, $debugger_port ) || die "failed to change unix socket privileges";
    }
}

sub get_debugger_client {
	my ( $self, $handler ) = @_;

	push @{$self->{ on_new_client }}, $handler;

	return if $self->{ state } eq 'waiting_client';
	$self->{ state } = 'waiting_client';

	my $client_host = $self->{ configuration }{ client_host } // die "missing client_host";
	my $client_port = $self->{ configuration }{ client_port } // die "missing client_port";

	tcp_connect(
		$client_host,
		$client_port,
		sub {
			my ( $client_fh ) = @_;

			print STDERR "Connected to a client\n";

			my $client = new MultiDbgp::Client( $client_fh );

			if( $client ) {
				$self->new_client($client);
				$self->{ state } = 'multiplexing';
				
				while( @{ $self->{ on_new_client } } ) {
					my $on_client_handler = shift @{$self->{ on_new_client }};
					$on_client_handler->( undef, $client )
				}
			}
			else {
				print STDERR "Client: $!\n";

				$self->{ state } = 'waiting_debugger';
				while( @{ $self->{ on_new_client } } ) {
					my $on_client_handler = shift @{$self->{ on_new_client }};
					$on_client_handler->( "failed client connection", undef );
				}
			}
		}
	);
}

sub detach_all_debuggers {
	my ( $self ) = @_;

	while( @{ $self->{ debuggers } } ) {
		my $debugger = shift @{$self->{ debuggers }};
		$debugger->command_detach();
	}
}

1;
