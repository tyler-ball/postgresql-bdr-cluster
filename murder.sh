#!/bin/bash

PID=`cat .pid`
echo killing $PID ...
kill -$PID 2> /dev/null
kill -9 -$PID 2> /dev/null
rm -f .pid
