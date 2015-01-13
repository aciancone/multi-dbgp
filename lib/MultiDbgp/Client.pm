package MultiDbgp::Client;
use strict;
use warnings;

use AnyEvent::Handle;
use AnyEvent::Socket;

use Data::Dumper;

sub new {
	my ($class, $client_fh ) = @_;

	if( !$client_fh ) {
		return;
	}

	my $self = bless {
		command_history		=> [],
		on_command_handlers	=> [],
		on_error_or_exit_handlers => [], 
	}, $class;

	$self->{ handler } = AnyEvent::Handle->new(
		fh => $client_fh,
		on_eof => sub {
			print STDERR "Client eof\n";

			for my $handler_info (@{ $self->{ on_error_or_exit_handlers } }) {
				my ( $handler, $context ) = @$handler_info;
				$handler->( $context, $self );
			}
		},
		on_error => sub {
			print STDERR "Client error: $!\n";
			print STDERR Data::Dumper::Dumper @_;

			for my $handler_info (@{ $self->{ on_error_or_exit_handlers } }) {
				my ( $handler, $context ) = @$handler_info;
				$handler->( $context, $self );
			}
		},
		on_read => sub {
			my ($client_handler) = @_;
	 
			$client_handler->push_read( line => "\x00", sub {
			        my ( $handle, $line, $eol ) = @_;

				print STDERR "cli::read\n";
#				print STDERR Data::Dumper::Dumper $line;
	 
				my $command = new MultiDbgp::Command( $line, $eol );
				push @{ $self->{ command_history } }, $command;
				for my $handler_info (@{ $self->{ on_command_handlers } }) {
					my ( $handler, $context ) = @$handler_info;
					$handler->( $context, $command );
				}
			});
		},
	);
	
	return $self;
}

sub get_all_precedent_commands {
	my ( $self ) = @_;

	# TODO return a copy
	return $self->{ command_history };
}

sub add_on_command_handler {
	my ( $self, $handler, $context ) = @_;

	push @{ $self->{ on_command_handlers } }, [ $handler, $context ];
}

sub add_on_error_or_exit_handler {
	my ( $self, $handler, $context ) = @_;

	push @{ $self->{ on_error_or_exit_handlers } }, [ $handler, $context ];
}

sub send_message {
	my ( $self, $message ) = @_;

	print STDERR "cli::write ". ( $message->get_transaction_id() || '' ) ."\n";
#	print STDERR Data::Dumper::Dumper $message->get_message();
	
	$self->{ handler }->push_write( $message->get_message() );
}

sub end {
    my ( $self ) = @_;

    $self->{ handler }->push_shutdown() if $self->{ handler };
}

1;
