#!/bin/bash

RESULTS=${2:-kube-apiserver-logs-$(date "+%F_%T")}

mkdir -p "$RESULTS"

echo "Collecting kube-apiserver logs"

# Operator log
oc logs -f $(oc get $(oc get pods -n openshift-kube-apiserver -o name | grep kube-apiserver-ip-10-0-x-x) -n openshift-kube-apiserver -o jsonpath='{.metadata.name}') -n openshift-kube-apiserver > $RESULTS/kube-apiserver-ip.log
