#!/bin/bash

./init-container.sh -a nagios2 --debug -c instances/nagios/


test_common
test_hook
test_cipher
