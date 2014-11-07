use strict;
use warnings;

use AnyEvent;
use AnyEvent::Socket;

use MultiDbgp::Debugger;
use MultiDbgp::Client;
use MultiDbgp::Dispatcher::LazySessionSelection;

use Data::Dumper;

my $cv = AE::cv;

my $dispatcher = new MultiDbgp::Dispatcher::LazySessionSelection( {
	debugger_host	=> undef,
	debugger_port	=> 9001,
	client_host	=> "localhost",
	client_port	=> 9000,
} );

$dispatcher->start();

$cv->recv;
