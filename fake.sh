#!/bin/bash -e

PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"

cat rssh.yaml | sed -e "s/__AUTHORIZED_KEYS__/$PUBLIC_KEY/g" | kubectl apply -f -

kubectl port-forward svc/rsshd-ssh 10022:22 &

ssh-keygen -R '[localhost]:10022' >/dev/null
ssh -p 10022 -R 10000:localhost:8000 -o ServerAliveInterval=60 root@localhost ping localhost > /dev/null

