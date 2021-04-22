#!/bin/bash

NAMESPACE="http-env-inject"
NAME="http-env-injector"

setup-sa() {
    bash ./script/webhook-create-signed-cert.sh --service ${NAME} --namespace ${NAMESPACE} --secret ${NAME}-tls
}

create-ns() {
    kubectl create ns ${NAMESPACE}
}

create-configmap() {
    kubectl create configmap mutate-policy -n ${NAMESPACE} --from-file=./kube/mutate.rego
}

create-mutationwebhook() {
cat <<EOF | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1beta1
kind: MutatingWebhookConfiguration
metadata:
  name: ${NAME}-admission-controller
webhooks:
  - name: mutating-webhook.openpolicyagent.org
    clientConfig:
      service:
        name: ${NAME}
        namespace: ${NAMESPACE}
      caBundle: $(kubectl get secret ${NAME}-tls -n ${NAMESPACE} -o 'go-template={{index .data "cert.pem"}}')
    rules:
      - operations: ["*"]
        apiGroups: ["*"]
        apiVersions: ["*"]
        resources: ["*"]
EOF
}

create-deployment() {
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: ${NAME}
  namespace: ${NAMESPACE}
  name: ${NAME}
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: ${NAME}
  template:
    metadata:
      labels:
        app: ${NAME}
      name: ${NAME}
    spec:
      containers:
        - image: openpolicyagent/opa
          name: opa
          ports:
          - containerPort: 443
          args:
          - "run"
          - "--server"
          - "--tls-cert-file=/certs/cert.pem"
          - "--tls-private-key-file=/certs/key.pem"
          - "--addr=0.0.0.0:443"
          - "--log-level=debug"
          - "--log-format=json"
          - "--format=pretty"
          - "/policies/mutate.rego"
          volumeMounts:
            - readOnly: true
              mountPath: /certs
              name: server-cert
            - readOnly: true
              mountPath: /policies
              name: mutate-policy
      volumes:
        - name: mutate-policy
          configMap:
            name: mutate-policy
        - name: server-cert
          secret:
            secretName: ${NAME}-tls

EOF
}

create-service() {
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ${NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${NAME}
spec:
  ports:
    - port: 443
      name: http
  selector:
    app: ${NAME}
EOF
}


deploy() {
    echo "Cleaning up old install.."
    cleanup
    echo "Deploying.."
    create-ns
    setup-sa
    create-mutationwebhook
    create-configmap
    create-deployment
    create-service
    echo "HTTP Env Injector Deployed."
}

cleanup() {
  kubectl delete ns/${NAMESPACE}
  kubectl delete MutatingWebhookConfiguration/${NAME}-admission-controller
}

helpmenu() {
  echo "Run --deploy to install"
  echo "Run --cleanup to uninstall"
}

update-configmap() {
  kubectl delete configmap/mutate-policy -n ${NAMESPACE}
  kubectl delete deploy/${NAME} -n ${NAMESPACE}
  create-configmap
  create-deployment
}


while [ ! $# -eq 0 ]
do
	case "$1" in
		--cleanup)
			cleanup
			exit
			;;
		--deploy)
			deploy
			exit
			;;
    --update-configmap)
			update-configmap
			exit
			;;
	esac
	shift
done
