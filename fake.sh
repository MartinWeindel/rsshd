#!/bin/bash -e

PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"
LOCAL_SSH_PORT=10022
SERVICE_BACKING_PORT_ON_POD=10000
LOCAL_SERVER_PORT=8000
NAMESPACE=default

cat "$(dirname "$0")"/rsshd.yaml | sed -e "s;__NAMESPACE__;$NAMESPACE;g" | sed -e "s;__AUTHORIZED_KEYS__;$PUBLIC_KEY;g" | kubectl apply -f -

while [ "$(kubectl get deploy rsshd -ojsonpath="{.status.readyReplicas}")" -lt 1 ]; do
  sleep 1
done

trapHandler()
{
 if [[ -n "$PID_PORT_FORWARD" ]]; then
    kill $PID_PORT_FORWARD
  fi
}

trap trapHandler SIGINT SIGTERM EXIT

kubectl port-forward svc/rsshd-ssh $LOCAL_SSH_PORT:22 &
PID_PORT_FORWARD=$!

ssh-keygen -R '[localhost]:10022' >/dev/null 2>&1 || true

while ! nc -vz localhost $LOCAL_SSH_PORT > /dev/null 2>&1; do
  sleep 1
done

ssh -p $LOCAL_SSH_PORT -R $SERVICE_BACKING_PORT_ON_POD:localhost:$LOCAL_SERVER_PORT -o ServerAliveInterval=60 -o StrictHostKeyChecking=accept-new root@localhost ping localhost > /dev/null

