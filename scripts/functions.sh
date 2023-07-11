#!/bin/bash

set -eu

location=$(dirname $0)

create_standard_users() {
  num=$1
  workload=${2:-0}
  prefix=$3

  echo "Creating $num standard users, $workload with workload, in namespaces $prefix..."

  pushd . > /dev/null
  cd $location && cd ../../toolchain-e2e || return
  go run setup/main.go --interactive=false --users $num --default $workload --custom 0 --username $prefix
  popd > /dev/null || return
}

create_custom_users() {
  template=$1
  num=$2
  prefix=$3

  echo "Creating $num custom users from template $template in namespaces $prefix..."

  full_template=$template
  if [[ ! $full_template == /* ]]
  then
    pushd . > /dev/null
    cd $location && cd ..
    full_template=$(pwd)/templates/$template
    popd > /dev/null || return
  fi

  pushd . > /dev/null
  cd $location && cd ../../toolchain-e2e || return
  go run setup/main.go --interactive=false --template $full_template --users $num --default 0 --custom $num --username $prefix
  popd > /dev/null || return
}

inject_peak_workload() {
  template=$1
  workload=${2:-0}
  parallelism=${3:-50}
  prefix=${4:-camel}

  echo "Injecting $workload users peak workload from template $template in namespaces $prefix..."

  full_template=$template
  if [[ ! $full_template == /* ]]
  then
    pushd . > /dev/null
    cd $location && cd ..
    full_template=$(pwd)/templates/$template
    popd > /dev/null || return
  fi

  pushd . > /dev/null
  cd $location && cd ..
  go run ./cmd/perf generate --parallelism $parallelism --number $workload --namespace-prefix $prefix $full_template
  popd > /dev/null || return
}

create_users_with_custom_build() {
  num=$1
  prefix=$2

  echo "Creating $num Camel users with custom build in namespaces $prefix..."

  pushd . > /dev/null
  cd $location && cd ../../toolchain-e2e/ || return

  for ((i=1;i<=$num;i++))
  do
    sed -e "s/build-property =.*$/build-property = $i/" ../camel-k-perf/templates/camel-build-template.yaml > /tmp/camel-build-$i.yaml

    go run setup/main.go --interactive=false --template /tmp/camel-build-$i.yaml --users 1 --default 0 --custom 1 --username $prefix-$i
  done

  popd > /dev/null || return
}
