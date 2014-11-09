package MultiDbgp::Command;
use strict;
use warnings;

use AnyEvent::Handle;
use AnyEvent::Socket;

use Data::Dumper;

sub new {
	my ($class, $raw, $eol ) = @_;

	my $self = bless {
		raw => $raw,
		eol => $eol,
	}, $class;

	$self->{ raw } = $raw;
	
	# TODO do a proper parsing
	# http://xdebug.org/docs-dbgp.php#message-packets
	# any special char can be can be part of an attribute value.
	# e.g. command -x "some -- text"
	my ( $command, $data ) = ( $raw, undef );
	if( $raw =~ /\s--\s/ ) {
		$raw =~ /(.*?)\s--\s(.*)$/;
		$command = $1;
		$data = $2;
	}
	$self->{ data } = $data;

	$command =~ /^([a-z]+)(\s(.*))?$/;
	$self->{ name } = $1;
	return $self if ! length $3;

	$self->{ args } = $3;

	if( $self->{ args } =~ /^((.*)\s)?-i\s([0-9]+)(\s(.*))?$/ ) {
		$self->{ transaction_id } = int $3;
		$self->{ args } = ( $2 && $5 ? $2." ".$5 : $2 || $5 || '');
	}
	
	return $self;
}

sub get_command {
	my ( $self, $transaction_id ) = @_;

	$transaction_id = $self->{ transaction_id } if ! defined $transaction_id;

	my $command = $self->{ name };
	$command .= " -i ". $transaction_id if defined $self->{ transaction_id };

	$command .= " ". $self->{ args } if $self->{ args };
	$command .= " -- ". $self->{ data } if $self->{ data };
	$command .= $self->{ eol };

	return $command;
}

sub is_detach {
	my ( $self ) = @_;

	return $self->{ name } eq 'detach';
}

1;
