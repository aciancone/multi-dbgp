#!/bin/bash

echo "Test lazy dispatched..."
# ~seconds	action
# 0		script B starts. it is connected to IDE
# 2		script C starts 
# 4		IDE send breakpoint and then run commands to B and C
# 5 		script C reach the break. It is exclusivelly connected to IDE
# 6		script A starts, receives a detach command, and end
# 8		script B reach the break, receives a detach command, and end
# 9 		C end

cd bin
perl dbgp-once_at_the_time.pl >&2 2> /dev/null &
multi_dbgp_pid=$!

sleep 1

(
	sleep 4
	echo 'Client> set breakpoint' >&2
	perl -e 'print "breakpoint_set -i 1 -t line -f file:///opt/projects/multi-dbgp/utils/stub_script.pl -n 8 -s enabled\x00"'
	sleep 1
	echo 'Client> run' >&2
	perl -e 'print "run -i 2\x00"'
	sleep 4
	echo 'Client> detach' >&2
	perl -e 'print "detach -i 3\x00"'
	sleep 3
) | nc -l 9000 > /dev/null &

# scripts using the debugged
( 
	cd ../utils
	. ./dbgp.environment
	(
		echo "Script B start" >&2
		perl -d ./stub_script.pl 3 B
		echo "Script B end" >&2
	)&
	(	
		sleep 2
		echo "Script C start" >&2
		perl -d ./stub_script.pl 0 C
		echo "Script C end" >&2 
	)&
	(
		sleep 7
		echo "Script A start" >&2
		perl -d ./stub_script.pl 0 A 
		echo "Script A end" >&2
	)&
) | grep -q "ABC" && echo "Result OK" || echo "Test FAILED"

kill $multi_dbgp_pid 
