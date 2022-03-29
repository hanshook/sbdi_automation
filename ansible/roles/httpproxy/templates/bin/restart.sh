#! /bin/bash
cd $(dirname $0)

. /opt/sbdi/lib/log_utils

cd ..

#TODO: Do this more cleverly... like by reloding or something?
./stop.sh
./start.sh

exit $?
