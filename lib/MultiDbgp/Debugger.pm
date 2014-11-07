package MultiDbgp::Debugger;
use strict;
use warnings;

use AnyEvent::Handle;
use AnyEvent::Socket;

use MultiDbgp::Command;
use MultiDbgp::Message;

use Data::Dumper;

sub new {
	my ($class, $debugger_fh ) = @_;

	if( !$debugger_fh ) {
		return;
	}

	my $self = bless {
		last_transaction_id		=> 0,
		command_queue	   		=> [],
		command_history	   		=> [],
		on_message_handlers		=> [],
		on_error_or_exit_handlers	=> [],
	}, $class;

	$self->{ event_handler } = AnyEvent::Handle->new(
		fh => $debugger_fh,
		on_eof => sub { 
			my ($handler, $fatal, $msg) = @_;
			print "dbg> eof\n";

			for my $handler_info ( @{ $self->{ on_error_or_exit_handlers } } ) {
				my ( $handler, $context ) = @$handler_info;
				$handler->( $context, $self, $fatal, $msg );
			}
		},
		on_error => sub {
			my ($handler, $fatal, $msg) = @_;
			print "dbg> error\n";

			for my $handler_info ( @{ $self->{ on_error_or_exit_handlers } } ) {
				my ( $handler, $context ) = @$handler_info;
				$handler->( $context, $self, $fatal, $msg );
			}
		},
		on_write => sub {
			my ( $handler ) = @_;

			$self->check_and_send_command();
		}

	);

	return $self; 
}

sub bind_to_client {
	my $self = shift;
	$self->{ client_event_handler } = shift;

	$self->{ client_event_handler }->on_read( sub {
		my ($client_handler) = @_;

		$client_handler->push_read( line => "\x00", sub {
			my ( $handler, $line, $eol ) = @_;

			print "cli> data\n";
			print STDERR Data::Dumper::Dumper $line, $eol;
			
			$self->{ event_handler }->push_write($line.$eol);
		});
	});
	$self->{ event_handler }->on_read( sub {
		my ($debugger_handler) = @_;

		$debugger_handler->push_read( line => "\x00", sub {
			my ( $handler, $line, $eol ) = @_;

			print "dbg>\n";
			print STDERR Data::Dumper::Dumper $line, $eol;

			$self->{ client_event_handler }->push_write($line.$eol);
		});
	});
}


sub command_continue {
	my $self = shift;

	$self->commands( [ new MultiDbgp::Command( "run -i ". $self->use_transaction_id, "\x00" ) ] );
}

sub command_detach {
	my $self = shift;

	$self->commands( [ new MultiDbgp::Command( "detach -i ". $self->use_transaction_id, "\x00" ) ] );
}

sub check_and_send_command {
	my $self = shift;

	return if ! @{ $self->{ command_queue } };

	return if @{ $self->{ command_history } } && ! grep { ! defined $_->{ response } } @{ $self->{ command_history } };

	my $command = shift $self->{ command_queue };
	my $transaction_id = $self->use_transaction_id();
	push $self->{ command_history }, {
		transaction_id => $transaction_id,
		command => $command,
		response => undef,
	};
	print STDERR "dbg::write\n";
#	print STDERR Data::Dumper::Dumper $command;
	$self->{ event_handler }->push_write( $command->get_command( $transaction_id ) );

	$self->{ event_handler }->push_read( line => "\x00", sub {
		shift;
		my $length = shift;

		$self->{ event_handler }->push_read( line => "\x00", sub {
			my ( $handler, $data, $eol ) = @_;
			my $message = new MultiDbgp::Message( $length, $data, $eol );
			my $response_transaction_id = $message->get_transaction_id();

			print STDERR "dbg::read\n";
#			print STDERR Data::Dumper::Dumper $message;

			my $related_command;
			if( defined $response_transaction_id ) {
				my @history_of_commands = grep { $_->{ transaction_id } eq $response_transaction_id } @{ $self->{ command_history } };
				die 'Unknown transaction id' if ! @history_of_commands;
				$history_of_commands[0]{ response } = $message;
				$related_command = $history_of_commands[0]{ command };
			}

			for my $on_message_handler_info ( @{ $self->{ on_message_handlers } } ) {
				print STDERR "message reply handlers ".Data::Dumper::Dumper scalar @{$self->{ on_message_handlers } };
				my ( $on_message_handler, $context ) = @$on_message_handler_info;
				$on_message_handler->( $context, $self, $message, $related_command );
			}

			$self->check_and_send_command();
		} );
	} );
}

sub commands {
	my ( $self, $commands ) = @_;

	push $self->{ command_queue }, $_ for @$commands;
	print STDERR "command queue size: ". scalar @{ $self->{ command_queue } } ."\n";
	$self->check_and_send_command();
}

sub add_on_error_or_exit_handler {
	my ( $self, $handler, $context ) = @_;
	push $self->{ on_error_or_exit_handlers }, [ $handler, $context ];
}

sub del_on_error_or_exit_handlers {
	my $self = shift;

	$self->{ on_error_or_exit_handlers } = [];
}

sub add_on_message_handler {
	my ( $self, $handler, $context ) = @_;
	push $self->{ on_message_handlers }, [ $handler, $context ];
}

sub del_on_message_handlers {
	my $self = shift;

	$self->{ on_message_handlers } = [];
}

sub use_transaction_id {
	my $self = shift;

	return $self->{ last_transaction_id }++;
}

sub start {
	my ( $self, $on_start_handler, $on_start_context ) = @_;

	$self->{ event_handler }->push_read( line => "\x00", sub {
		shift;
		my $length = shift;
		$self->{ event_handler }->push_read( line => "\x00", sub {
			my ( $self_handler, $data, $eol ) = @_;
			my $message = new MultiDbgp::Message( $length, $data, $eol );
			my $response_transaction_id = $message->get_transaction_id();

			print STDERR "dbg::read\n";
#			print STDERR Data::Dumper::Dumper $message;

			$on_start_handler->( $on_start_context, $self, $message );
		});
	});
}

1;
