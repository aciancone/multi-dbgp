use Test::Simple;
use Test::More;

use MultiDbgp::Message;

my $no_transaction_id = <<END;
<?xml version="1.0" encoding="UTF-8" ?>
<response command="breakpoint_set"
          status="run"
          id="123"/>
END

my $transaction_id_zero = <<END;
<?xml version="1.0" encoding="UTF-8" ?>
<response command="breakpoint_set"
          transaction_id="0"
          status="run"
          id="123"/>
END

my $transaction_id_one = <<END;
<?xml version="1.0" encoding="UTF-8" ?>
<response command="breakpoint_set"
          transaction_id="1"
          status="run"
          id="123"/>
END

my $message_status_break = <<END;
<?xml version="1.0" encoding="UTF-8" ?>
<response command="breakpoint_set"
          transaction_id="0"
          status="break"
          id="123"/>
END

my $message_status_running = <<END;
<?xml version="1.0" encoding="UTF-8" ?>
<response command="breakpoint_set"
          transaction_id="0"
          status="running"
          id="123"/>
END

my $step_into = <<END;
<?xml version="1.0" encoding="UTF-8" ?>
<response xmlns="urn:debugger_protocol_v1" command="step_into"
					status="break"
					reason="ok" transaction_id="2"/>
END

# urn:debugger_protocol_v1

is( new MultiDbgp::Message(160, $step_into, "\x00")->is_debugger_in_break_status(), 1, "step_into response");
is( new MultiDbgp::Message(length $message_status_break, $message_status_break, "\x00")->is_debugger_in_break_status(), 1, "message with break status");
is( new MultiDbgp::Message(length $message_status_running, $message_status_running, "\x00")->is_debugger_in_break_status(), 0, "message with running status");

is( new MultiDbgp::Message(length $no_transaction_id, $no_transaction_id, "\x00")->get_transaction_id(), undef, "message without transaction id");
is( new MultiDbgp::Message(length $transaction_id_one, $transaction_id_one, "\x00")->get_transaction_id(), 1, "message with transaction id one");
is( new MultiDbgp::Message(length $transaction_id_zero, $transaction_id_zero, "\x00")->get_transaction_id(), 0, "message with transaction id zero");

done_testing();

