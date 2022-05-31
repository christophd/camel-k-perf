#!/bin/bash

set -eu

echo "Running scenario 06: Suddenly love for Kamelets"

location=$(dirname $0)
source $location/functions.sh

create_standard_users 1400 0 camel-06-normal
create_custom_users camel-kamelet.yaml 600 camel-06-kamelet
