#!/bin/bash

set -euo pipefail

# Centralized user-data logging
LOG=/root/userdata.log
mkdir -p /root
touch "$LOG"
chmod 600 "$LOG"
exec > >(tee -a "$LOG" | logger -t user-data -s 2>/dev/console) 2>&1
trap 'echo "ERROR at line $LINENO"; exit 1' ERR

echo "user-data start: $(date -Is)"

# SSM agent
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# Base packages
apt-get update -y
export DEBIAN_FRONTEND=noninteractive
apt-get install -y \
  less unzip realmd adcli \
  samba samba-common-bin samba-libs oddjob oddjob-mkhomedir packagekit \
  krb5-user nano vim nfs-common winbind libpam-winbind libnss-winbind stunnel4

# EFS utils
cd /tmp
git clone https://github.com/mamonaco1973/amazon-efs-utils.git
cd amazon-efs-utils
dpkg -i amazon-efs-utils*.deb
which mount.efs

# AWS CLI v2
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# EFS mounts
mkdir -p /efs
echo "${efs_mnt_server}:/ /efs efs _netdev,tls 0 0" >> /etc/fstab
systemctl daemon-reload
mount /efs

mkdir -p /efs/home /efs/data
echo "${efs_mnt_server}:/home /home efs _netdev,tls 0 0" >> /etc/fstab
systemctl daemon-reload
mount /home

# AD join
secretValue=$(aws secretsmanager get-secret-value \
  --secret-id ${admin_secret} \
  --query SecretString \
  --output text)

admin_password=$(echo "$secretValue" | jq -r '.password')
admin_username=$(echo "$secretValue" | jq -r '.username' | sed 's/.*\\//')

echo -e "$admin_password" | realm join \
  --client-software=winbind \
  --membership-software=samba \
  -U "$admin_username" \
  ${domain_fqdn} \
  --verbose

# SSH tweaks — identity is handled entirely by winbind via smb.conf below.
# Short login names (jsmith, not jsmith@domain) come from "winbind use default
# domain = yes"; home dir + shell come from the "template" lines in smb.conf.
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' \
  /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

touch /etc/skel/.Xauthority
chmod 600 /etc/skel/.Xauthority
# Enable pam_winbind (domain auth) and auto-create home dirs on first login
pam-auth-update --enable winbind --enable mkhomedir
systemctl restart ssh

# Samba — stop winbind while we lay down our tuned smb.conf
systemctl stop winbind

cat > /tmp/smb.conf <<EOF
[global]
workgroup = ${netbios}
security = ads

strict sync = no
sync always = no
aio read size = 1
aio write size = 1
use sendfile = yes

passdb backend = tdbsam

printing = cups
printcap name = cups
load printers = yes
cups options = raw

kerberos method = secrets and keytab

template homedir = /home/%U
template shell = /bin/bash
#netbios

create mask = 0770
force create mode = 0770
directory mask = 0770
force group = ${force_group}

realm = ${realm}

# Read POSIX uidNumber/gidNumber straight from AD (RFC2307) so UIDs are
# authoritative and identical across every host and the file share — the same
# result the old SSSD ldap_id_mapping=False gave us, but winbind does it alone.
# unix_nss_info = no: users.json sets uid/gid but NOT loginShell, so fall back
# to the "template shell/homedir" above instead of AD's (empty) shell attribute.
idmap config ${realm} : backend = ad
idmap config ${realm} : schema_mode = rfc2307
idmap config ${realm} : unix_nss_info = no
idmap config ${realm} : range = 10000-1999999999
idmap config * : backend = tdb
idmap config * : range = 1-9999

winbind use default domain = yes
winbind normalize names = yes
winbind refresh tickets = yes
winbind offline logon = yes
winbind enum groups = yes
winbind enum users = yes
winbind cache time = 30
idmap cache time = 60
winbind negative cache time = 0

[homes]
browseable = no
read only = no
inherit acls = yes

[efs]
path = /efs
read only = no
guest ok = no
EOF

cp /tmp/smb.conf /etc/samba/smb.conf
rm /tmp/smb.conf

head /etc/hostname -c 15 > /tmp/netbios-name
value=$(</tmp/netbios-name)
value=$(echo "$value" | tr -d '-' | tr '[:lower:]' '[:upper:]')
export netbios="$${value^^}"
sed -i "s/#netbios/netbios name=$netbios/" /etc/samba/smb.conf

cat > /tmp/nsswitch.conf <<EOF
passwd:     files winbind
group:      files winbind
shadow:     files winbind
hosts:      files dns myhostname
services:   files
netgroup:   nis
EOF

cp /tmp/nsswitch.conf /etc/nsswitch.conf
rm /tmp/nsswitch.conf

systemctl restart winbind smb nmb

# Sudo + permissions
echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10-linux-admins
sed -i 's/^\(\s*HOME_MODE\s*\)[0-9]\+/\10700/' /etc/login.defs

su -c "exit" rpatel
su -c "exit" jsmith
su -c "exit" akumar
su -c "exit" edavis

chgrp mcloud-users /efs /efs/data
chmod 770 /efs /efs/data
chmod 700 /home/*

cd /efs
git clone https://github.com/mamonaco1973/aws-efs.git
chmod -R 775 aws-efs
chgrp -R mcloud-users aws-efs
