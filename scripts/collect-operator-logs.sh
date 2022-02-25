#!/bin/bash

RESULTS=${2:-operator-logs-$(date "+%F_%T")}

mkdir -p "$RESULTS"

echo "Collecting operator logs"

# Operator log
oc logs -f $(oc get $(oc get pods -n openshift-operators -o name | grep camel-k-operator) -n openshift-operators -o jsonpath='{.metadata.name}') -n openshift-operators > $RESULTS/camel-k-operator.log
