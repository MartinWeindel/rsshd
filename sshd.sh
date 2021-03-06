#!/usr/bin/env ash

# This is the main startup script for the running sshd to keep client
# tunnels.

# Settings directory
SDIR="$HOME/etc/ssh"

mkdir -p $SDIR
cp /etc/ssh/* $SDIR

# Directory for HOSTKEYS
KEYS=$SDIR/keys
mkdir -p $KEYS

# Generate server keys, if necessary. ssh-keygen generates the keys in the
# default directory, not where we want the keys, so we move the keys once they
# have been generated.
if [ ! -f "${KEYS}/ssh_host_rsa_key" ]; then
    # One shot generation, -A really is for init.d style startup script, but
    # this is what we sort of are.
    ssh-keygen -A -f $HOME
    
    # Move the keys to the location that we want
    if [ -f "$SDIR/ssh_host_rsa_key" ]; then
        mv $SDIR/ssh_host_rsa_key $KEYS/ssh_host_rsa_key
        mv $SDIR/ssh_host_rsa_key.pub $KEYS/ssh_host_rsa_key.pub
    fi
    if [ -f "$SDIR/ssh_host_dsa_key" ]; then
        mv $SDIR/ssh_host_dsa_key $KEYS/ssh_host_dsa_key
        mv $SDIR/ssh_host_dsa_key.pub $KEYS/ssh_host_dsa_key.pub
    fi
    if [ -f "$SDIR/ssh_host_ecdsa_key" ]; then
        mv $SDIR/ssh_host_ecdsa_key $KEYS/ssh_host_ecdsa_key
        mv $SDIR/ssh_host_ecdsa_key.pub $KEYS/ssh_host_ecdsa_key.pub
    fi
    if [ -f "$SDIR/ssh_host_ed25519_key" ]; then
        mv $SDIR/ssh_host_ed25519_key $KEYS/ssh_host_ed25519_key
        mv $SDIR/ssh_host_ed25519_key.pub $KEYS/ssh_host_ed25519_key.pub
    fi

fi

# add hostkey to config as we using custom configuration
cat >> $SDIR/sshd_config << EOM

Port 2222
HostKey $KEYS/ssh_host_rsa_key
HostKey $KEYS/ssh_host_ecdsa_key
HostKey $KEYS/ssh_host_ed25519_key
EOM

# Arrange for the config to point at the proper server keys, i.e. at the proper
# location
if [ -f "$KEYS/ssh_host_rsa_key" ]; then
    sed -i "s;\#HostKey $SDIR/ssh_host_rsa_key;HostKey $KEYS/ssh_host_rsa_key;g" $SDIR/sshd_config
fi
if [ -f "$KEYS/ssh_host_dsa_key" ]; then
    sed -i "s;\#HostKey $SDIR/ssh_host_dsa_key;HostKey $KEYS/ssh_host_dsa_key;g" $SDIR/sshd_config
fi
if [ -f "$KEYS/ssh_host_ecdsa_key" ]; then
    sed -i "s;\#HostKey $SDIR/ssh_host_ecdsa_key;HostKey $KEYS/ssh_host_ecdsa_key;g" $SDIR/sshd_config
fi
if [ -f "$KEYS/ssh_host_ed25519_key" ]; then
    sed -i "s;\#HostKey $SDIR/ssh_host_ed25519_key;HostKey $KEYS/ssh_host_ed25519_key;g" $SDIR/sshd_config
fi

# Allow external hosts to connect
if [ -z "$LOCAL" -o "$LOCAL" == 0 ]; then
    sed -i "s;\GatewayPorts no;GatewayPorts yes;g" $SDIR/sshd_config
    sed -i "s;\AllowTcpForwarding no;AllowTcpForwarding yes;g" $SDIR/sshd_config
    sed -i "s;\#PermitRootLogin .*;PermitRootLogin yes;g" $SDIR/sshd_config
fi

mkdir "$HOME/.ssh"
chown app:app $HOME/.ssh
chmod 755 $HOME/.ssh

if [ -n "$AUTHORIZED_KEYS" ]; then
  echo "$AUTHORIZED_KEYS" >  $HOME/.ssh/authorized_keys
fi

# Absolute path necessary! Pass all remaining arguents to sshd. This enables to
# override some options through -o, for example.
/usr/sbin/sshd -f ${SDIR}/sshd_config -D -e "$@"
