#!/bin/bash

echo "Running scenario 01: Look there's a Camel"

location=$(dirname $0)
cd $location

TEST_ID=01 \
TEST_N=3000 \
TEST_C=100 \
TEST_CR=10 \
TEST_CB=10 \
TEST_CP=1 \
TEST_NC=900 \
TEST_P=0 \
./create-load.sh
