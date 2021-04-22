

setup-sa() {
    bash ./script/webhook-create-signed-cert.sh --service mutate-example --namespace demo-mutate --secret mutate-example-tls
}

create-ns() {
    kubectl create ns demo-mutate
}

create-configmap() {
    kubectl create configmap mutate-policy -n demo-mutate --from-file=./kube/mutate.rego
}

create-mutationwebhook() {
cat <<EOF >>
apiVersion: admissionregistration.k8s.io/v1beta1
kind: MutatingWebhookConfiguration
metadata:
  name: mutate-example-admission-controller
webhooks:
  - name: mutating-webhook.openpolicyagent.org
    clientConfig:
      service:
        name: mutate-example
        namespace: demo-mutate
      caBundle: $(kubectl get secret mutate-example-tls -n demo-mutate -o 'go-template={{index .data "cert.pem"}}')
    rules:
      - operations: ["*"]
        apiGroups: ["*"]
        apiVersions: ["*"]
        resources: ["*"]
EOF
}

create-deployment() {
    kubectl apply -f kube/deployment.yaml
}


main() {
    create-ns
    setup-sa
    create-mutationwebhook
    create-configmap
    create-deployment
}

main