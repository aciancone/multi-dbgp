use Test::Simple;
use Test::More;

use MultiDbgp::Command;

is( new MultiDbgp::Command("command", "\x00")->get_command(76), "command\x00", "only command");

is( new MultiDbgp::Command("command -i 0", "\x00")->get_command(), "command -i 0\x00", "command with transaction id");

is( new MultiDbgp::Command("command -i 0", "\x00")->get_command(78), "command -i 78\x00", "command with new transaction id");

is( new MultiDbgp::Command("command -j 6", "\x00")->get_command(78), "command -j 6\x00", "command without transaction id");

is( new MultiDbgp::Command("command -j xxx -i 10 -a 12 -- data", "\x00")->get_command(79), "command -i 79 -j xxx -a 12 -- data\x00", "command with data and arguments");

done_testing();
