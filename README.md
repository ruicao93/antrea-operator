# Antrea Operator

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## Overview

The Antrea Operator installs [Antrea](https://github.com/vmware-tanzu/antrea/)
CNI plugin on an OpenShift Kubernetes cluster.
The operator will be deployed in the early phases of cluster
deployment, and it will take care of deploying Antrea components:

* The antrea-controller deployment
* The antrea-agent daemonset

For Openshift 4 clusters, the antrea-operator monitors cluster network
configuration CRD(`Network.config.openshift.io/v1`) object to update the
container network CIDRs and service network CIDRs used by Antrea.

The antrea-operator also monitors a dedicated CRD(`AntreaInstall`) object,
applies changes to antrea-controller and antrea-agent configuration, and
restarts the relevant pods so that the relevant configuration changes are
picked up.

## Try it out

Generate install-config.yaml by using openshift-install command.
```
$ openshift-install --dir=MY_CLUSTER create install-config
```

Edit `MY_CLUSTER/install-config.yaml` to update networking section.
Change `networkType` to `antrea`(case insensitive).
Set container network CIDRs `clusterNetwork` and `serviceNetwork` in
`MY_CLUSTER/install-config.yaml`.

Create manifest files:
```
$ openshift-install --dir=MY_CLUSTER create manifests
```
Put operator yaml files from `deploy/` and `deploy/crds/` to
`MY_CLUSTER/manifests`. Edit `operator.antrea.vmware.com_v1_antreainstall_cr.yaml`
to set Antrea configurations and image version.

Generate ignition configuration files:
```
$ openshift-install --dir=MY_CLUSTER create ignition-configs
```
This bootstrap ignition file will be added to the terraform tfvars.
Then use terraform to install Openshift 4 cluster on vSphere.

### Build & Run

Building the antrea-operator is very simple. From the project root
directory simply type the following command.

```
make all
```

At the moment the antrea-operator only works on Openshift 4
environments.

## Documentation

### Cluster network config
Cluster network config is initially set in install-config.yaml, user could apply
`Network.config.openshift.io` CRD to update `clusterNetwork` and
`serviceNetwork` in `manifests/cluster-network-02-config.yml`.

*Example configurations*
```
apiVersion: config.openshift.io/v1
kind: Network
metadata:
  name: cluster
spec:
  clusterNetwork:
  - cidr: 10.10.0.0/14
  networkType: antrea
```

### Operator CR
Operator CR `antrea-install` is used to provide antrea configurations:
- AntreaAgentConfig holds the configurations for antrea-agent.
- AntreaCNIConfig holds the configurations of CNI.
- AntreaControllerConfig holds the configurations for antrea-controller.
- AntreaImage is the Antrea image name and version used by antrea-agent and antrea-controller.

## License

This repository is available under the [Apache 2.0 license](LICENSE).
