#!/bin/bash -e

DT=$(date "+%F_%T")
RESULTS=${RESULTS:-results-$DT}
mkdir -p $RESULTS

USER_NS_PREFIX=${1:-camel}

# Resource counts
resource_counts(){
    echo -n "$1;"
    # All resource counts from user namespaces
    echo -n "$(oc get $1 --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace --ignore-not-found=true | grep $USER_NS_PREFIX | wc -l)"
    echo -n ";"
    # All resource counts from all namespaces
    echo "$(oc get $1 --all-namespaces -o name --ignore-not-found=true | wc -l)"
}

# Dig various timestamps out
timestamps(){
    CR_JSON=$1
    DEPLOYMENTS_JSON=$2
    OPERATOR_LOG=$3
    RESULTS=$4

    LOG_SEG_DIR=$RESULTS/operator-log-segments
    mkdir -p $LOG_SEG_DIR

    jq -rc '((.metadata.namespace) + ";" + (.metadata.name) + ";" + (.metadata.creationTimestamp) + ";" + (if (.status == null) then ("") else (.status.conditions[] | select(.type=="Ready").lastTransitionTime) end ))' $CR_JSON > $RESULTS/tmp.csv
    echo "Integration;Created;ReconciledTimestamp;Ready;RunningTimestamp" > $RESULTS/cr-timestamps.csv
    for i in $(cat $RESULTS/tmp.csv); do
        ns=$(echo -n $i | cut -d ";" -f1)
        name=$(echo -n $i | cut -d ";" -f2)
        echo -n $ns/$name;
        echo -n ";";
        echo -n $(format_date $(echo -n $i | cut -d ";" -f3));
        echo -n ";";
        log=$LOG_SEG_DIR/$ns.log
        cat $OPERATOR_LOG | grep $ns > $log
        reconcile_ts=$(cat $log | jq -rc 'if ."request-namespace" != null then select(."request-namespace" | contains("'$ns'")) | select(.msg | contains("Reconciling Integration")).ts else empty end' | head -n1)
        if [ -n "$reconcile_ts" ]; then
            echo -n $(format_date "$reconcile_ts" "+%F %T" "%s");
        fi
        echo -n ";";
        echo -n $(format_date $(echo -n $i | cut -d ";" -f4));
        echo -n ";";
        done_ts=$(cat "$log" | jq -rc 'if ."phase-to" != null then select(."phase-to" | contains("Running")) | select(."request-namespace" | contains("'$ns'")).ts else empty end' | head -n1)
        if [ -n "$done_ts" ]; then
            echo $(format_date "$done_ts" "+%F %T" "%s")
        else
            echo ""
        fi
    done >> $RESULTS/cr-timestamps.csv
    rm -f $RESULTS/tmp.csv

    jq -rc '((.metadata.namespace) + ";" + (.metadata.name) + ";" + (.metadata.creationTimestamp) + ";" + (.status.conditions[] | select(.type=="Available") | select(.status=="True").lastTransitionTime))' $DEPLOYMENTS_JSON > $RESULTS/tmp.csv
    echo "Namespace;Deployment;Deployment_Created;Deployment_Available;Integration_Name;Integration_Created;Integration_ReconciledTimestamp;Integration_Ready;Integration_RunningTimestamp" > $RESULTS/integration-timestamps.csv
    for i in $(cat $RESULTS/tmp.csv); do
        NS=$(echo -n $i | cut -d ";" -f1);
        echo -n $NS;
        echo -n ";";
        echo -n $(echo -n $i | cut -d ";" -f2);
        echo -n ";";
        echo -n $(format_date $(echo -n $i | cut -d ";" -f3));
        echo -n ";";
        echo -n $(format_date $(echo -n $i | cut -d ";" -f4));
        echo -n ";";
        cat $RESULTS/cr-timestamps.csv | grep $NS
    done >> $RESULTS/integration-timestamps.csv
    rm -f $RESULTS/tmp.csv
}

# Format date of different input formats (e.g. ISO 8601 compliant date/time string) to given output format.
format_date(){
    DATE=$1
    OUTPUT_FORMAT=${2:-"+%F %T"}
    INPUT_FORMAT=${3:-"%Y-%m-%dT%H:%M:%SZ"}

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ "$OUTPUT_FORMAT" == "%s" ]]; then
            DATE="@$DATE"
        fi

        echo $(date -d "$DATE" "$OUTPUT_FORMAT");
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # MacOS
        echo -n $(date -j -f "$INPUT_FORMAT" $(echo -n "$DATE" | cut -d "." -f1) "$OUTPUT_FORMAT");
    else
        echo "$DATE"
    fi
}

echo "Collecting integration results"
# Collect timestamps
{
# Integration resources in user namespaces
oc get integrations --all-namespaces -o json | jq -r '.items[] | select(.metadata.namespace | contains("'$USER_NS_PREFIX'"))' > $RESULTS/integrations.json

# Deployment resources in user namespaces
oc get deployment --all-namespaces -o json | jq -r '.items[] | select(.metadata.namespace | contains("'$USER_NS_PREFIX'" )) | select(.metadata.name | contains("camel-k-perf"))' > $RESULTS/deployments.json

# Operator log
oc logs $(oc get $(oc get pods -n openshift-operators -o name | grep camel-k-operator) -n openshift-operators -o jsonpath='{.metadata.name}') -n openshift-operators > $RESULTS/camel-k-operator.log

timestamps $RESULTS/integrations.json $RESULTS/deployments.json $RESULTS/camel-k-operator.log $RESULTS
} &

echo "Collecting resource counts"
# Collect resource counts
{
oc api-resources --verbs=list --namespaced -o name | sort > resource-list.namespaced
oc api-resources --verbs=list --namespaced=false -o name | sort > resource-list.cluster
RESOURCE_COUNTS_OUT=$RESULTS/resource-count.csv
echo "Resource;UserNamespaces;AllNamespaces" > $RESOURCE_COUNTS_OUT
for i in $(cat resource-list.namespaced resource-list.cluster | sort); do
    resource_counts $i >> $RESOURCE_COUNTS_OUT;
    echo -n "."
done
} &

wait
