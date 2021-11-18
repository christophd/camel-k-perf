#!/bin/bash

set -eu

echo "Running scenario 02: Suddenly love for Camel"

location=$(dirname $0)
source $location/functions.sh

create_standard_users 2000 0 camel-02-empty
create_custom_users camel-no-resources.yaml 990 camel-02-nores
create_custom_users camel-full.yaml 10 camel-02-full
