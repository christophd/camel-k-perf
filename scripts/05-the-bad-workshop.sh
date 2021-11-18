#!/bin/bash

echo "Running scenario 05: The bad workshop"

location=$(dirname $0)
cd $location

TEST_ID=05 \
TEST_N=3000 \
TEST_C=100 \
TEST_CR=0 \
TEST_CB=0 \
TEST_CP=100 \
TEST_NC=0 \
TEST_P=1 \
./create-load.sh
