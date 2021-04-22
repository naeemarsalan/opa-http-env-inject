

setup-sa() {
    bash ./script/webhook-create-signed-cert.sh --service mutate-example --namespace demo-mutate --secret mutate-example-tls
}

create-ns() {
    kubectl create ns demo-mutate
}

create-configmap() {
    kubectl create configmap mutate-policy -n demo-mutate --from-file=./kube/mutate.rego
}

create-deployment() {
    kubectl apply -f kube/deployment.yaml
}

main() {
    create-ns
    setup-sa
    create-configmap
    create-deployment
}

main