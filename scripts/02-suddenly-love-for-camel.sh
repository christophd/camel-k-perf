#!/bin/bash

set -eu

echo "Running scenario 02: Suddenly love for Camel"

location=$(dirname $0)
source $location/functions.sh

create_standard_users 1000 0 camel-02-empty
create_custom_users camel-no-resources.yaml 900 camel-02-nores
create_custom_users camel-full.yaml 100 camel-02-full
