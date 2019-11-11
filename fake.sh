#!/bin/bash -e

PUBLIC_KEY_PATH=~/.ssh/id_rsa.pub
LOCAL_SSH_PORT=10022
SERVICE_BACKING_PORT_ON_POD=10000
LOCAL_SERVER_PORT=8000
NAMESPACE=default
DEBUG_LABEL_VALUE=rsshd

usage()
{
    cat <<EOM
Usage:
Runs local webhook on remote ssh server for service

./fake.sh [-d] [-n <namespace>] [--ssh-port <port>] [-r <port>] [-l <port>] [--public-key <path>]

Options:
    -n <namespace>         kubernetes namespace to deploy sshd & service ($NAMESPACE)
    --ssh-port <port>      local ssh port ($LOCAL_SSH_PORT)
    -r <port>              service backing port on pod ($SERVICE_BACKING_PORT_ON_POD)
    -l <port>              local server port ($LOCAL_SERVER_PORT)
    --debug-label <value>  debug label value ($DEBUG_LABEL_VALUE)
    --public-key <path>    path to ssh public key ($PUBLIC_KEY_PATH)
    -d                     delete kubernetes deployment

Example: ./fake.sh -n extension-foo-bar
EOM
}

while [ "$1" != "" ]; do
    case $1 in
        -n )   shift
               NAMESPACE=$1
               shift
               ;;
        -r )   shift
               SERVICE_BACKING_PORT_ON_POD=$1
               shift
               ;;
        -l )   shift
               LOCAL_SERVER_PORT=$1
               shift
               ;;
        -d )   shift
               DELETE=true
               ;;
        --ssh-port )    shift
                        LOCAL_SSH_PORT=$1
                        shift
                        ;;
        --debug-label ) shift
                        DEBUG_LABEL_VALUE=$1
                        shift
                        ;;
        --public-key )  shift
                        PUBLIC_KEY=$1
                        shift
                        ;;
        * )             usage
                        exit 1
    esac
done

trapHandler()
{
 if [[ -n "$PID_PORT_FORWARD" ]]; then
    kill $PID_PORT_FORWARD
  fi
}

trap trapHandler SIGINT SIGTERM EXIT

PUBLIC_KEY="$(cat "$PUBLIC_KEY_PATH")"

delete()
{
  cat "$(dirname "$0")"/rsshd.yaml | sed -e "s;__DEBUG_LABEL_VALUE__;$DEBUG_LABEL_VALUE;" | sed -e "s;__NAMESPACE__;$NAMESPACE;g" | sed -e "s;__AUTHORIZED_KEYS__;$PUBLIC_KEY;g" | kubectl delete -f -
}

create()
{
  cat "$(dirname "$0")"/rsshd.yaml | sed -e "s;__DEBUG_LABEL_VALUE__;$DEBUG_LABEL_VALUE;" | sed -e "s;__NAMESPACE__;$NAMESPACE;g" | sed -e "s;__AUTHORIZED_KEYS__;$PUBLIC_KEY;g" | kubectl apply -f -

  while [ "$(kubectl -n "$NAMESPACE" get deploy rsshd -ojsonpath="{.status.readyReplicas}")" -lt 1 ]; do
    sleep 1
  done

  kubectl -n "$NAMESPACE" port-forward svc/rsshd-ssh $LOCAL_SSH_PORT:22 &
  PID_PORT_FORWARD=$!

  ssh-keygen -R '[localhost]:10022' >/dev/null 2>&1 || true

  while ! nc -vz localhost $LOCAL_SSH_PORT > /dev/null 2>&1; do
    sleep 1
  done

  echo "opening tunnel"
  ssh -p $LOCAL_SSH_PORT -R $SERVICE_BACKING_PORT_ON_POD:localhost:$LOCAL_SERVER_PORT -o ServerAliveInterval=60 -o StrictHostKeyChecking=accept-new root@localhost ping localhost > /dev/null
}

if [ "$DELETE" == "true" ]; then
  delete
else
  create
fi
