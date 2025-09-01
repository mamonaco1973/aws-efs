#!/bin/bash

#--------------------------------------------------------------------
# Ensure SSM Agent is installed and running for remote management
#--------------------------------------------------------------------
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# This script automates the process of updating the OS, installing required packages,
# joining an Active Directory (AD) domain, configuring system settings, and cleaning
# up permissions.

# ---------------------------------------------------------------------------------
# Section 1: Update the OS and Install Required Packages
# ---------------------------------------------------------------------------------

# Update the package list to ensure the latest versions of packages are available.
apt-get update -y

# Set the environment variable to prevent interactive prompts during installation.
export DEBIAN_FRONTEND=noninteractive

# Install necessary packages for AD integration, system management, and utilities.
# - realmd, sssd-ad, sssd-tools: Tools for AD integration and authentication.
# - libnss-sss, libpam-sss: Libraries for integrating SSSD with the system.
# - adcli, samba-common-bin, samba-libs: Tools for AD and Samba integration.
# - oddjob, oddjob-mkhomedir: Automatically create home directories for AD users.
# - packagekit: Package management toolkit.
# - krb5-user: Kerberos authentication tools.
# - nano, vim: Text editors for configuration file editing.
apt-get install -y less unzip realmd sssd-ad sssd-tools libnss-sss \
    libpam-sss adcli samba-common-bin samba-libs oddjob \
    oddjob-mkhomedir packagekit krb5-user nano vim nfs-common \
    winbind libpam-winbind libnss-winbind

# ---------------------------------------------------------------------------------
# Section 2: Install AWS CLI
# ---------------------------------------------------------------------------------

# Change to the /tmp directory to download and install the AWS CLI.
cd /tmp

# Download the AWS CLI installation package.
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o "awscliv2.zip"

# Unzip the downloaded package.
unzip awscliv2.zip

# Install the AWS CLI using the installation script.
sudo ./aws/install

# Clean up by removing the downloaded zip file and extracted files.
rm -f -r awscliv2.zip aws

# ---------------------------------------------------------------------------------
# Section 3: Mount EFS file system
# ---------------------------------------------------------------------------------

mkdir -p /efs
echo "${efs_mnt_server}:/ /efs nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0" | sudo tee -a /etc/fstab
systemctl daemon-reload
mount /efs
mkdir -p /efs/home
mkdir -p /efs/data
echo "${efs_mnt_server}:/home /home nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0" | sudo tee -a /etc/fstab
systemctl daemon-reload
mount /home

# ---------------------------------------------------------------------------------
# Section 4: Join the Active Directory Domain
# ---------------------------------------------------------------------------------

# Retrieve the secret value (AD admin credentials) from AWS Secrets Manager.
# - ${admin_secret}: The name of the secret containing the AD admin credentials.
secretValue=$(aws secretsmanager get-secret-value --secret-id ${admin_secret} \
    --query SecretString --output text)

# Extract the admin password from the secret value using `jq`.
admin_password=$(echo $secretValue | jq -r '.password')

# Extract the admin username from the secret value and remove the domain prefix.
admin_username=$(echo $secretValue | jq -r '.username' | sed 's/.*\\//')

# Join the Active Directory domain using the `realm` command.
# - ${domain_fqdn}: The fully qualified domain name (FQDN) of the AD domain.
# - Log the output and errors to /tmp/join.log for debugging.
#echo -e "$admin_password" | sudo /usr/sbin/realm join -U "$admin_username" \
#    ${domain_fqdn} --verbose \
#    >> /tmp/join.log 2>> /tmp/join.log

echo -e "$admin_password" | sudo /usr/sbin/realm join --membership-software=samba -U "$admin_username" \
    ${domain_fqdn} --verbose >> /tmp/join.log 2>> /tmp/join.log

# ---------------------------------------------------------------------------------
# Section 5: Allow Password Authentication for AD Users
# ---------------------------------------------------------------------------------

# Modify the SSH configuration to allow password authentication for AD users.
# - Replace `PasswordAuthentication no` with `PasswordAuthentication yes`.
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' \
    /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

# ---------------------------------------------------------------------------------
# Section 6: Configure SSSD for AD Integration
# ---------------------------------------------------------------------------------

# Modify the SSSD configuration file to simplify user login and home directory creation.
# - Disable fully qualified names (use only usernames instead of user@domain).
sudo sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/g' \
    /etc/sssd/sssd.conf

# Disable LDAP ID mapping to use UIDs and GIDs from AD.
sudo sed -i 's/ldap_id_mapping = True/ldap_id_mapping = False/g' \
    /etc/sssd/sssd.conf

# Change the fallback home directory path to a simpler format (/home/%u).
sudo sed -i 's|fallback_homedir = /home/%u@%d|fallback_homedir = /home/%u|' \
    /etc/sssd/sssd.conf

# Stop XAuthority warning 

touch /etc/skel/.Xauthority
chmod 600 /etc/skel/.Xauthority

# Restart the SSSD and SSH services to apply the changes.

sudo pam-auth-update --enable mkhomedir
sudo systemctl restart ssh

# ---------------------------------------------------------------------------------
# Section 8: Configure file server
# ---------------------------------------------------------------------------------

sudo systemctl stop sssd

cat <<EOT >  /tmp/smb.conf
# See smb.conf.example for a more detailed config file or
# read the smb.conf manpage.
# Run 'testparm' to verify the config is correct after
# you modified it.

[global]
workgroup = ${netbios}
security = ads

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

#idmap backend = tdb
#idmap gid = 10000-2000000
#idmap uid = 10000-2000000

idmap config ${realm} : backend = sss
idmap config ${realm} : range = 10000-1999999999

idmap config * : range = 1-9999
idmap config * : backend = tdb

min domain uid = 0
winbind use default domain = no
winbind refresh tickets = yes
winbind offline logon = yes
winbind enum groups = no
winbind enum users = no

[homes]
comment = Home Directories
browseable = No
read only = No
inherit acls = Yes

[efs]
comment = Mounted EFS area
path = /efs
read only = no
guest ok = no
EOT

sudo cp /tmp/smb.conf /etc/samba/smb.conf
sudo rm /tmp/smb.conf
head /etc/hostname -c 15 > /tmp/netbios-name
value=$(</tmp/netbios-name)
export netbios="$${value^^}"
sudo sed -i "s/#netbios/netbios name=$netbios/g" /etc/samba/smb.conf

cat <<EOT >  /tmp/nsswitch.conf
#
# /etc/nsswitch.conf
#
# An example Name Service Switch config file. This file should be
# sorted with the most-used services at the beginning.
#
# The entry '[NOTFOUND=return]' means that the search for an
# entry should stop if the search in the previous entry turned
# up nothing. Note that if the search failed due to some other reason
# (like no NIS server responding) then the search continues with the
# next entry.
#
# Valid entries include:
#
#	nisplus			Use NIS+ (NIS version 3)
#	nis			Use NIS (NIS version 2), also called YP
#	dns			Use DNS (Domain Name Service)
#	files			Use the local files
#	db			Use the local database (.db) files
#	compat			Use NIS on compat mode
#	hesiod			Use Hesiod for user lookups
#	[NOTFOUND=return]	Stop searching if not found so far
#

# To use db, put the "db" in front of "files" for entries you want to be
# looked up first in the databases
#
# Example:
#passwd:    db files nisplus nis
#shadow:    db files nisplus nis
#group:     db files nisplus nis

#passwd:     files sss winbind
passwd:     files sss winbind
group:      files sss winbind
automount:  files sss winbind
shadow:     files sss winbind

#group:      files sss winbind

#hosts:     db files nisplus nis dns
hosts:      files dns myhostname

# Example - obey only what nisplus tells us...
#services:   nisplus [NOTFOUND=return] files
#networks:   nisplus [NOTFOUND=return] files
#protocols:  nisplus [NOTFOUND=return] files
#rpc:        nisplus [NOTFOUND=return] files
#ethers:     nisplus [NOTFOUND=return] files
#netmasks:   nisplus [NOTFOUND=return] files

bootparams: nisplus [NOTFOUND=return] files

ethers:     files
netmasks:   files
networks:   files
protocols:  files
rpc:        files
services:   files sss

netgroup:   files sss

publickey:  nisplus

#automount:  files sss
aliases:    files nisplus

EOT

sudo cp /tmp/nsswitch.conf /etc/nsswitch.conf
sudo rm /tmp/nsswitch.conf

sudo systemctl restart winbind
sudo systemctl restart smb
sudo systemctl restart nmb
sudo systemctl restart sssd

# ---------------------------------------------------------------------------------
# Section 7: Grant Sudo Privileges to AD Linux Admins
# ---------------------------------------------------------------------------------

# Add a sudoers rule to grant passwordless sudo access to members of the
# "linux-admins" AD group.
sudo echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/10-linux-admins

# ---------------------------------------------------------------------------------
# Section 8: Force home directory creation in NFS and set default permissions
# ---------------------------------------------------------------------------------

su -c "exit" rpatel
su -c "exit" jsmith
su -c "exit" akumar
su -c "exit" edavis
chgrp mcloud-users /efs
chgrp mcloud-users /efs/data 
chmod 770 /efs
chmod 770 /efs/data 

# ---------------------------------------------------------------------------------
# End of Script
# ---------------------------------------------------------------------------------