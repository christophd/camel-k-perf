#!/bin/bash

set -eu

echo "Running scenario 02: Suddenly love for Camel"

location=$(dirname $0)
source $location/functions.sh

create_standard_users 1400 1400 camel-02-normal
create_custom_users camel-no-resources.yaml 600 camel-02-nores
