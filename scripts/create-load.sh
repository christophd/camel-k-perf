#!/bin/bash

set -eu
test_id=${TEST_ID}
test_n=${TEST_N}
test_c=${TEST_C}
test_cr=${TEST_CR}
test_cb=${TEST_CB}
test_cp=${TEST_CP}
test_nc=${TEST_NC}
test_p=${TEST_P}

test_batch=${TEST_BATCH:-10}

test_n_tot=$(($test_n - $test_c))
test_c_tot=$(($test_c - $test_cr - $test_cb + 1 - $test_cp))
test_cb_real=$(($test_cb - 1)) # one build is created by standard Camel users
if [[ "$test_cb" -eq 0 ]]; then test_c_tot=0; fi

location=$(dirname $0)
cd $location && cd ..

run_load() {
  peak=$1
  num=$2
  num_workload=$3
  template=$4
  prefix=$5

  full_template=$template
  if [[ ! $full_template == /* ]]
  then
    full_template=$(pwd)/templates/$template
  fi

  batch_num=$test_batch
  if [ $(( $num % $batch_num )) -ne 0 ]
  then
    batch_num=1
  fi

  if [[ "$num" -le 0 ]]
  then
    return 0
  fi

  if [[ "$peak" -gt 0 ]]
  then
      pushd . > /dev/null
      cd ../toolchain-e2e

      go run setup/main.go \
            --users $num \
            --batch $batch_num \
            --default 0 \
            --custom 0 \
            --username $prefix
      popd > /dev/null

      go run ./cmd/perf \
            generate \
            --number $num_workload \
            --namespace-prefix $prefix \
            $full_template
  else
      pushd . > /dev/null
      cd ../toolchain-e2e
      if [ -z "$template" ]
      then
        go run setup/main.go \
            --users $num \
            --batch $batch_num \
            --default $num_workload \
            --custom 0 \
            --username $prefix
      else
        go run setup/main.go \
            --template $full_template \
            --users $num \
            --batch $batch_num \
            --default 0 \
            --custom $num_workload \
            --username $prefix
      fi
      popd > /dev/null
  fi
}

echo "Creating $test_n_tot standard users of which $test_nc with workload..."
run_load 0 $test_n_tot $test_nc "" camel-$test_id-normal

if [[ "$test_cb_real" -gt 0 ]]
then
  for ((i=1;i<=$test_cb_real;i++))
  do
    sed -e "s/build-property =.*$/build-property = $i/" ../camel-k-perf/templates/camel-build-template.yaml > /tmp/camel-build-$i.yaml

    echo "Creating $i/$test_cb_real Camel user that produces a build (not using Memory/CPU)..."
    run_load $test_p 1 1 /tmp/camel-build-$i.yaml camel-$test_id-camel-build
  done
fi

echo "Creating $test_cp Camel users with their own platform (not using Memory/CPU)..."
run_load $test_p $test_cp $test_cp camel-platform.yaml camel-$test_id-camel-platform

echo "Creating $test_c_tot Camel users not using Memory/CPU..."
run_load $test_p $test_c_tot $test_c_tot camel-no-resources.yaml camel-$test_id-camel-nores

echo "Creating $test_cr full Camel users..."
run_load $test_p $test_cr $test_cr camel-full.yaml camel-$test_id-camel-full
