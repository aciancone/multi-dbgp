package MultiDbgp::Message;
use strict;
use warnings;

use XML::LibXML;

sub new {
	my ($class, $length, $raw, $eol ) = @_;

  	my $dom = XML::LibXML->load_xml(string => $raw );
	my $xc  = XML::LibXML::XPathContext->new($dom);
	$xc->registerNs('debugger_protocol_v1', 'http://xdebug.org/dbgp/xdebug');

	my $self = bless {
		length => $length,
		raw => $raw,
		dom => $dom,
		xc  => $xc,
		eol => $eol,
	}, $class;

	return $self;
}

sub is_debugger_in_break_status {
	my ( $self ) = @_;

	return 0 unless $self->{ dom } && ref $self->{ dom };

	for my $node ( $self->{ dom }->findnodes('//*') ) {
		next if( $node->nodeName() ne 'response' );
		my $status = $node->findvalue( '@status' );
		return 1 if $status eq 'break';
	}

	return 0;
}

sub get_transaction_id {
	my ( $self ) = @_;

	return 0 unless $self->{ dom } && ref $self->{ dom };

	for my $node ( $self->{ dom }->findnodes('//*') ) {
		next if( $node->nodeName() ne 'response' );
		my $id = $node->findvalue( '@transaction_id' );
		return int $id if length $id;
	}

	return undef;
}

sub get_app_id {
	my ( $self ) = @_;

	return 0 unless $self->{ dom } && ref $self->{ dom };

	for my $node ( $self->{ dom }->findnodes('//*') ) {
		next if( $node->nodeName() ne 'init' );
		my $appid = $node->findvalue( '@appid' );
		return $appid if defined $appid;
	}

	return undef;
}

sub get_message {
	my ( $self ) = @_;

	return $self->{ length }.$self->{ eol }.$self->{ raw }.$self->{ eol }
}

1;
