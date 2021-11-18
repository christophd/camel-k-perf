#!/bin/bash

echo "Running scenario 04: Good cameleers share builds"

location=$(dirname $0)
cd $location

TEST_ID=04 \
TEST_N=3000 \
TEST_C=1000 \
TEST_CR=10 \
TEST_CB=51 \
TEST_CP=0 \
TEST_NC=0 \
TEST_P=1 \
./create-load.sh
