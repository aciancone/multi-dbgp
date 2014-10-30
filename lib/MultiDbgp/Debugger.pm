package MultiDbgp::Debugger;
use strict;
use warnings;

use AnyEvent::Handle;
use AnyEvent::Socket;

sub new {
	my ($class, $debugger_fh ) = @_;

	if( !$debugger_fh ) {
		return;
	}

	my $self = bless {
		transaction_id => 0
	}, $class;

	$self->{debugger_event_handler} = AnyEvent::Handle->new(
		fh => $debugger_fh,
		on_eof => sub { 
			my ($handler, $fatal, $msg) = @_;
			print "dbg> eof\n";
		},
		on_error => sub {
			my ($handler, $fatal, $msg) = @_;
			print "dbg> error\n";
		},
	);

	return $self; 
}

sub bind_to_client {
	my $self = shift;
	$self->{client_event_handler} = shift;

	$self->{client_event_handler}->on_read( sub {
		my ($client_handler) = @_;

		$client_handler->push_read( line => "\x00", sub {
			my ( $handle, $line, $eol ) = @_;

			print "cli> data\n";
			print STDERR Data::Dumper::Dumper $line, $eol;
			
			$self->{debugger_event_handler}->push_write($line.$eol);
		});
	});
	$self->{debugger_event_handler}->on_read( sub {
		my ($debugger_handler) = @_;

		$debugger_handler->push_read( line => "\x00", sub {
			my ( $handle, $line, $eol ) = @_;

			print "dbg>\n";
			print STDERR Data::Dumper::Dumper $line, $eol;

			$self->{client_event_handler}->push_write($line.$eol);
		});
	});
}

sub command_continue {
	my $self = shift;

	$self->{debugger_event_handler}->push_read( line => "\x00", sub {
		my ( $handle, $line, $eol ) = @_;
		
		print "ph> cmd run\n";
		$self->{debugger_event_handler}->push_write("run -i ". $self->use_transaction_id ."\x00");
	});
}

sub command_detach {
	my $self = shift;

	$self->{debugger_event_handler}->push_read( line => "\x00", sub {
		my ( $handle, $line, $eol ) = @_;
		
		print "ph> cmd detach\n";
		$self->{debugger_event_handler}->push_write("detach -i ". $self->use_transaction_id ."\x00");
	});
}

sub use_transaction_id {
	my $self = shift;

	# TODO atomic increment
	return $self->{transaction_id}++;
}

1;
