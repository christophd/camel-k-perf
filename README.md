# Camel K Performance Tests

This repository contains script to setup performance tests for Camel K 
for the [Red Hat OpenShift Dev Sandbox](https://developers.redhat.com/developer-sandbox) environment.

In particular, the scripts focus on generating specific load profiles that
may affect the overall performance of the operator.

Also the repository provides some scripts to collect metrics during and after the test run.

## Requirements

### 1. Setup dev sandbox cluster 

A dev sandbox cluster is an arbitrary OpenShift cluster e.g. on AWS with

* master nodes of  "m5.4xlarge" size (16 vCPU, 64 GiB Memory)
* worker noddes of "m5.2xlarge" size (8 vCPU, 32 GiB Memory)

There is a [sample installation configuration](https://github.com/codeready-toolchain/toolchain-e2e/tree/master/setup#prereqs) provided by the sandbox team.

### 2. Prepare local tooling

The host running the performance test needs to have some tooling installed. 
Please prepare all required tools on your local machine (see the list of required tools):

Required pre-installed tools:
* go 1.16 or later
* git
* operator-sdk 1.8.0
* sed
* yamllint
* jq
* yq (python-yq from [github.com/kislyuk/yq](https://github.com/kislyuk/yq#installation), other distributions may not work)
* podman (if you need to use docker, then run the make targets with this variable set: IMAGE_BUILDER=docker)
* opm ([mirror.openshift.com](https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/) or [github.com/operator-framework/operator-registry](https://github.com/operator-framework/operator-registry/releases) - the version should correspond with the OpenShift version you are running)

### 3. Prepare quay.io account

There is a set of images that is built and pushed to quay repositories while deploying local versions of Toolchain (Sandbox) operators to OpenShift cluster. 
We need to make sure that the repositories exist in the quay.io account that is used to perform the performance tests.

The repositories to create in the Quay account are listed in
[codeready-toolchain/toolchain-e2e/quay.adoc](https://github.com/codeready-toolchain/toolchain-e2e/blob/master/quay.adoc) 

When running the performance tests you need to login to that quay account before hand (e.g. using the docker CLI `docker login quay.io`)

### 4. Deploy toolchain-e2e sandbox resources

The scripts in this repository assume that the `camel-k-perf` repository is checked out in the same directory
as the [toolchain-e2e](https://github.com/codeready-toolchain/toolchain-e2e).

I.e. from the root of this repository, the following command should return with no errors:

```
ls ../toolchain-e2e
```

Follow the instructions on the [toolchain-e2e setup guide](https://github.com/codeready-toolchain/toolchain-e2e/tree/master/setup)
to install a test dev sandbox environment on a cluster, up to the point of populating the cluster with users.

Actual population will be done with the scripts in this repository.

### 5. Install Camel K

Install the Camel K operator under test. The operator needs to be installed **globally** in the cluster.

Refer to the [upstream Camel K installation guide](https://camel.apache.org/camel-k/next/installation/installation.html) or
to the Red Hat documentation if you want to test the product version.

### 6. Enable Camel K operator metrics

The Camel K operator exposes metrics that can be consumed by the Openshift monitoring stack. 
Ensure to have this ConfigMap in the namespace `openshift-monitoring`

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
 name: cluster-monitoring-config
 namespace: openshift-monitoring
data:
 config.yaml: |
   enableUserWorkload: true
```

You can apply the resource in the openshift-monitoring namespace

```shell
oc apply -f monitoring/cluster-monitoring-config.yaml -n openshift-monitoring
```

Also add a PodMonitor CR in the `openshift-operators` namespace so the Camel K operator metrics show up in the Prometheus scraping

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
 name: camel-k-operator
 labels:
   app: "camel-k"
   camel.apache.org/component: operator
spec:
 selector:
   matchLabels:
     app: "camel-k"
     camel.apache.org/component: operator
 podMetricsEndpoints:
   - port: metrics
```

Just apply the resource in the openshift-operators namespace

```shell
oc apply -f monitoring/operator-pod-monitor.yaml -n openshift-operators
```

We are now ready to run some tests.

## Running Tests

### Collecting metrics

Before running any test script we need to constantly grab performance metrics from the cluster throughout the test run. 
You can start collecting metrics with the script

```shell
./scripts/collect-metrics.sh
```

The script periodically collects metrics from cluster nodes and user namespaces. 
The script collects the metrics every 30 seconds and saves the results as CSV to your local machine.

Keep the process running in background when executing the tests. 
You may want to collect metrics some time before and after the test run, too.

### Test scenarios

Pick your test from the `scripts` directory and launch it from a shell.

Current scripts include:

- `01-look-there-a-camel.sh`: Wanting to be optimistic, 10% of active dev sandbox users will be using Camel K. Here we test that the operator does not interfere with others’ workloads.
- `02-suddenly-love-for-camel.sh`: When a lot of people fall in love with Camel, they try the hello world altogether. We want to ensure that the time to get an integration ready is adequate.
- `03-the-summit-live-workshop.sh`: This is a variation of scenario 2 where all people hit the button to create the integration in the same exact moment.
- `04-good-cameleers-share-builds.sh`: Assuming 5% of the integrations generated by the users are going to create a build, we measure how the builds are serialized and the shape of users' wait times.
- `05-the-bad-workshop.sh`: Workshop instructions tell the users to create an integration platform in their namespaces. This leads to parallel builds executed in the same moment.

### Collect test results

After the test run you should collect some results. 
This includes gathering of Camel K integration KPIs (e.g. time-to-ready, time-to-running) and a full overview of created resources on the cluster.

When to start collecting the results? Shortly after the test script has finished all Camel users are provisioned on the cluster. 
It may take some time though for the operator to start all integrations. 
It is essential to wait for the integrations to become ready before starting to collect the results otherwise you will not get all duration metrics for that.

You can watch the metric `camel_k_integration_first_readiness_seconds_count` on the OCP web console. 
This counts the integrations on the cluster that have reached the ready state.

Once the integrations are ready please run the script

```shell
./scripts/collect-results.sh <USER_NS_PREFIX>
```

This will gather some results from the cluster and save it to your local machine for later analysis. 
The user namespace prefix argument limits the number of namespaces to look for Camel K integrations. 
Usually this is a prefix constructed from the used test scenario number e.g. `camel-01` for scenario `01-look-there-a-camel.sh` and  `camel-02` for scenario `02-suddenly-love-for-camel.sh`.

## Result analysis

Once you have executed the scripts to collect the metrics and results you will find new output folders in the camel-k-perf project.

The folders look like this:

* results-YYYY-MM-DD_HH:mm:ss
  * operator-log-segments
  Directory holding operator logs for the individual Camel user namespaces
  * camel-k-operator.log => full operator log
  * cr-timestamps.csv => Intermediate summary of timestamps for integration CRs
  * deployments.json => List of Camel integration deployments on the cluster
  * integration-timestamps.csv => Summarized set of timestamps per Camel integration
  * integrations.json => List of Camel integration CRs on the cluster
  * resource-count.csv => Summary of created resources on the cluster


* metrics-YYYY-MM-DD_HH:mm:ss
  * nodes.info
  * nodes.yaml
  * node-info.ip-<ip.address>.eu-west-1.compute.internal.csv
  * pod-info.camel-k-operator-<id>.csv
  * pod-info.cluster-monitoring-operator-<id>.csv
  * pod-info.<namespace>-<id>.csv
