## Kubernetes Mutation Webhook for Environment Variables (HTTP/HTTPS Proxy Example)

This example uses OPA deployment with rego policy attached as config map. As this is workaround for now until OPA Gatekeeper promates this feature to Stable.

Currently OPA Gatekeeper has plan to implement this into upstream. Currently this feature is Beta and can be tracked here:
https://github.com/open-policy-agent/gatekeeper/milestone/9

## To Add Enviroment Variables edit the follwoing file line 38/39
`deploy/kube/mutate.rego`

## To install Mutating Webhook Run the following Script
`./deploy/install.sh --deploy`

## To deploy changes for mutate.rego after deploy run --update-configmap
`./deploy/install.sh --update-configmap`


## To uninstall Mutating Webhook Run the following Script
`./deploy/install.sh --cleanup`
## How to use:
To enable kubernetes resource to have enviroment variables you will have to add annotation:
`kubectl annotate deployment nginx http-proxy=true -n demo-mutate`



This was created with the help of the following github issue:
https://github.com/open-policy-agent/opa/issues/943

