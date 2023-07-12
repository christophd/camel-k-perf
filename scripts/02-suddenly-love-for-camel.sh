#!/bin/bash

set -eu

echo "Running scenario 02: Suddenly love for Camel"

location=$(dirname $0)
source $location/functions.sh

create_standard_users 1400 0 camel-02-normal
create_custom_users_no_install camel-full.yaml 600 camel-02-full
