---
title: Backup and Restore System
---

**Innehållsförteckning**

[Short Summary 2](#short-summary)

[Intended use of this document 2](#intended-use-of-this-document)

[Status 2](#status)

[Design principles 3](#design-principles)

[The phases of a backup 3](#the-phases-of-a-backup)

[The phases of a backup restore 3](#the-phases-of-a-backup-restore)

[Gluster and gluster snapshots 3](#gluster-and-gluster-snapshots)

[Logical volume based local storage
3](#logical-volume-based-local-storage)

[ZFS Backup Target 4](#zfs-backup-target)

[Possible week points 4](#possible-week-points)

[Rsync 5](#rsync)

[Possible problems with performance
5](#possible-problems-with-performance)

[SSH and parallel ssh 5](#ssh-and-parallel-ssh)

[Introduce more parallelism to speed up backups
6](#introduce-more-parallelism-to-speed-up-backups)

[Security 6](#security)

[Remaining security issues to consider
9](#remaining-security-issues-to-consider)

[Docker Swarm integration 10](#docker-swarm-integration)

[Dependencies 10](#dependencies)

[Ansible playbook integration 10](#ansible-playbook-integration)

[1. The backup director virtual machine
10](#the-backup-director-virtual-machine)

[2. Backup operator user 11](#backup-operator-user)

[3. The backup target node 11](#the-backup-target-node)

[4. Docker swarm control 12](#docker-swarm-control)

[5. The backup source nodes 12](#the-backup-source-nodes)

[Operations reference 12](#operations-reference)

[To access backup operations 12](#to-access-backup-operations)

[To list existing backup operations
12](#to-list-existing-backup-operations)

[To run a backup 12](#to-run-a-backup)

[To list existing backups 12](#to-list-existing-backups)

[To restore backups 13](#to-restore-backups)

[Pausing and unpausing docker containers
13](#pausing-and-unpausing-docker-containers)

[Automating backup 13](#automating-backup)

[Way forward -- remaining issues 14](#way-forward-remaining-issues)

[Overview reference 14](#overview-reference)

# 

# Short Summary

The backup and restore system is part of the SBDI deployment platform.
It provides the following primary services:

1\. Saving a complete and consistent snapshot of all data and
configuration of the SBDI system at a given point in time.

2\. Restoring any such snapshot of all data and configuration to a
running deployment

In other words, if backups are run regularly, in case of for instance a
fatal disaster the last, or any valid backup, may be restored and
operations may continue from the state that was present at the backup.

Secondary services also provided by the backup system are:\
1. Off site backup replication, i.e. all backups are not only stored on
the deployment system but synchronized off site.

2\. Partial restore of a specific service, like Word Press, email or a
specific database.\
3. Restore to another deployment which is intended to be used to
transfer production data to a test deployment or to another deployment
in case SBDI has to be moved.

A key factor important to understanding the backup and restore system is
that it is designed from the ground up to be a part of the SBDI
deployment platform. It is deployed by an Ansible playbook based on the
same inventory information that is used to deploy the platform itself.
Consequently, apart from backup storage volume size, no configuration
specific to the backup and restore system is needed. Also the SBDI
deployment platform is designed from the beginning to work optimally
with the backup system. This applies to such things as name conventions,
where data is placed, network setup, which file systems are used etc.

Also the backup and restore system is designed making full use of the
fact that SBDI is dockerized. For instance the system uses docker pause
and resume in order to ensure the integrity and consistency of backup
data. Also the system will manage the docker swarm when backups are
restored in order to ensure the integrity and consistency of backup
data.

# Intended use of this document

The intended use of this document is that a reasonably experienced Linux
systems administrator should be able to fully understand how the Backup
and Restore system is designed, installed, maintained and how it may be
operated and further developed.

# Status 

As of September 2022 primary services are fully implemented and tested
(with sample data) and ready for automated use.\
Secondary services, except off site replication, are implemented, not
fully tested and not automated. In order to use those functions
initiated manual operations are required. Off site replication is based
on ZFS replication and thus implemented but, as of now, needs to be
configured and setup manually.

# Design principles

This section is intended to provide knowledge about how the backup and
restore system works and why as well as on how to maintain it.\
Since the backup and restore system has not been fully deployed also
possible future problems and how to resolve them are addressed.

## The phases of a backup

\<short introductory text\>

## The phases of a backup restore

\<Short description on how a backup is restored\>

## Gluster and gluster snapshots

The deployment platform uses GlusterFS
(https://docs.gluster.org/en/latest/) to store docker swarm images.\
There currently exists only one Gluster volume called docker that is
provided by the nodes manager-\[1..3\]. This gluster volume is mounted
at /docker on all host nodes of the docker swarm. In the filesystem
mounted under /docker all SBDI docker volumes (except Cassandra and
Solr) as well as configuration resides in a well defined directory
structure.

Thus by taking a snapshot of the docker Gluster volume and rsyncing it
to the backup target node we may backup all SBDI containers (except
Cassandra and Solr) in one strike.

To snapshot the Gluster volume we rely on Gluster
(https://docs.gluster.org/en/main/Administrator-Guide/Managing-Snapshots/)
thus fore instance we have to use thinly provisioned LVM on the manager
nodes.

During backup a snapshot of the Gluster volume is taken on the manager-1
node and mounted at /gluster_backupsource after rsyncing that filesystem
to the backup target the snapshot is removed.

It is worth pointing out that during the time of the rsync the Gluster
snapshot will gradually take up more and more space as the SBDI system
performs its task (backup does not interrupt operations). It is
essential to make sure there is enough space on the thinly provisioned
LVM backing device to support that growth. In essence it might not be a
good idea to import or process a lot of new data into the system or make
big changes during the rsync phase of the backup.

## Logical volume based local storage

The deployment platform uses LVM to store Cassandra and Solr data
locally. The backup system makes use of that in order to backup that
data.

The local data for Cassandra and Solr is kept on a logical volume called
lv_docker_local that is mounted at /docker_local.

During a backup the backup system will, using parallel ssh, take
snapshots of the lv_docker_local volumes on all Cassandra and Solr nodes
and mount the snapshots at /local_backupsource.

After using rsync to synchronize the data under /local_backupsource to
the backup target host the snapshots are unmounted and removed.

Since parallel ssh is only parallel and not transactional all docker
containers are paused in the entire SBDI system prior to taking the
snapshots to ensure that all snapshots are a consistent representation
of the data of the system at that time.

As with the Gluster snapshots also LVM snapshots grow when the data
changes on the filesystem they are derived from. Since backup does not
interrupt SBDI system operations it is important to ensure that there is
enough space on the device backing the LVM. It is therefore suggested
that large imports of data sets or indexing operations are not
undertaken during backup.

## ZFS Backup Target

It is easy to confuse the term "backup target". One might think of it as
either the data that we intend to backup (probably the most natural
association?) or the result of the backup procedure, i.e. the backup
itself. We use the second alternative and thus with "backup target" we
refer to the the desired result and representation of a backup.

For backup storage ZFS
(<https://openzfs.org/wiki/System_Administration>) and ZFS snapshots and
clones
(<https://ubuntu.com/tutorials/using-zfs-snapshots-clones#1-overview>)
in combination with high compression (gzip-7) are used.\
Piggy backing onto ZFS we will get incremental backups (snapshots), low
disk usage (high compression), data synchronization (ZFS off site
replication) in combination with proven high grade data safekeeping for
free.

### Possible week points

Since the backup and restore system has not been tested with full SBDI
data volumes it might be relevant if backups tend to be very slow that

1.  High performance ZFS is known to be RAM and CPU hungry, the backup
    target node may have to be provided with more of those.

2.  Tuned ZFS that are performing large amounts of synchronous writes
    may benefit from a ZIL cache. A backup does most likely involve a
    large amounts of synchronous writes but a ZIL cache, i.e. a fast SSD
    may not be added in the intended Open Stack deployment. How to
    handle this type of performance problem in this case has to be
    investigated.

3.  The writer of this document has previous experience with performance
    degradation of ZFS in virtual machines when the disk is provided via
    network such as is the case both at SNIC and NRM. The use of
    ephemeral disk would probably be much better if performance turns
    out to be degraded.

The above are examples of possible problems that may or may not occur.
It is however a fair assumption that ZFS will be able to deliver good
enough performance at lest for normal incremental day to day backups.
With a full scale first backup of \~ 5TB+ however things become more
uncertain. An alternative to ZFS might be btrfs
(<https://btrfs.wiki.kernel.org/index.php/Main_Page>) and might be a
suggested option to try but to this point no other close match to our
requirements with better performance are known to us. But in case of
performance issues also other possible bottlenecks must be considered
like rsync and network performance.

## Rsync

Backups make heavy use of rsync in order to transfer data to the backup
target server (<https://en.wikipedia.org/wiki/Rsync>). On paper rsync is
absolutely ideal for the intended use since it only transfers those
files that has been changed which in normal SBDI case on a day to day
basis is a tiny fraction of all files.

SBDI is normally a "read only" system since big changes occurs only when
new data sets are imported. This should make incremental daily backups
based on rsync very fast. However since SBDI data consists of a very
large quantity of small files success is not guarantied and it is
important to test performance and consider tuning when the SBDI system
is fully loaded with data.

### Possible problems with performance

Since we are running rsync over ssh all communication is encrypted. This
is a good candidate bottleneck for performance. Following is just a
couple of suggestions that may be tried if backups turns out to takes
days in stead of hours:

1.  Use a lighter encryption algorithm, i.e. like -e \"ssh -c arcfour\".

2.  Do not use any encryption - for instance with HPN-SSH
    (<https://www.psc.edu/hpn-ssh-home/>). This is should be acceptable
    since the internal network of the SBDI deployment platform is well
    protected.

3.  Consider removing atime from file systems mounts.

4.  Consider using rsync with -W option or possibly compression.

5.  Use jumbo frame, MTU networking.

It is important to realize that accepting terrible performance should
not be necessary. The basic design should be able to perform well.
Tuning it to swiftness however might invole systematic work.

## SSH and parallel ssh 

The backup and restore system entirely relies on ssh in order to execute
its distributed task.

When taking and removing snapshots parallel ssh is used since all
snapshots not only can easily but should ideally be be taken at the same
instance in time in order to ensure the consistency of the backup.

When syncing backup data from the snapshots to the backup target server
these rsync tasks are performed in sequence. This is by design since it
is reasonable to assume that running several rsync tasks in parallel
against one backup target server will most likely slow down operations.

Furthermore the rsync phase does not have to be performed in a hurry
since the data to backup is safe on the snapshots.

### Introduce more parallelism to speed up backups

In case backups turn out to be to slow to be practical and tuning, as
suggested in other sections of this paper, turns out to not solve the
issue there always remains the option of introducing more than one
backup target. The general idea here is that the backup system works
precisely as now but that the backup is divided up, for instance one
backup target node per Solar and Cassandra. This will be very possible
but since we do not know if the design change is necessary it is just
indicated here.

## Security

The backup operator user has access to almost all machines in the system
and must have root access in order to read and restore data and system
state. In order for such a powerful system agent not to be able to bad
things in case of malfunction, incorrect setup or if it was compromised
the following patterns and principles have been followed in the design
of the backup and restore system:

1)  The backup operator is an unprivileged user without a password, i.e.
    it can not do general sudo "on its own" and it is not possible to
    login as backup operator as exemplified by:

\$cat /etc/passwd \| grep backupoperator

backupoperator:x:1901:1901::/home/backupoperator:/bin/bash

\$cat /etc/shadow \| grep backupoperator

backupoperator:!:19117:0:99999:7:::

\$cat /etc/group \| grep backupoperator

backupoperator:x:1901:

2)  The privileged operations that the backup operator performs have
    (with one exception -- see below) been capsuled into only a few
    scripts that needs to be run with sudo, i.e. these capsule scripts
    include the various low level commands that on their own (not
    encapsulated) may be used to do many other (potentially harmful)
    things.

3)  These scripts have no arguments or switches of functional character,
    i.e. if they do not have bugs they are not supposed to be used for
    performing any other (potentially harmful) task than their intended.

4)  Further more these scripts (if there are no bugs in the Ansible
    installation tasks!) have been given file permissions ensuring that
    they may not be modified without root access as exemplified by the
    scripts on the manger-1 node:

/opt/sbdi/backup/bin\# ls -lrth

total 48K

-rwxr-xr-x 1 root root 422 May 5 14:51 start_docker

-rwxr-xr-x 1 root root 441 May 5 14:51 stop_docker

-rwxr-xr-x 1 root root 617 May 5 14:51 pause_containers

-rwxr-xr-x 1 root root 634 May 5 14:51 unpause_containers

-rwxr-xr-x 1 root root 3.5K May 5 14:52
prepare_source_snapshot.gluster.sh

-rwxr-xr-x 1 root root 2.1K May 5 14:52
remove_source_snapshot.gluster.sh

-rwxr-xr-x 1 root root 4.1K Jul 14 12:44 prepare_source_snapshot.lvm.sh

-rwxr-xr-x 1 root root 2.5K Jul 14 12:44 remove_source_snapshot.lvm.sh

-rwxr-xr-x 1 root root 341 Sep 2 07:50 prepare_source_snapshot

-rwxr-xr-x 1 root root 2.0K Sep 2 07:50 perform_rsync

-rwxr-xr-x 1 root root 341 Sep 2 07:50 remove_source_snapshot

5)  Also these scripts are generated by the Ansible installation tasks
    in such a way that all configuration is hardcoded into the scripts,
    i.e. there are no configuration files (that may be manipulated or
    include incorrect settings).

Thus the template script file
ansible/roles/backup/source/templates/bin/prepare_source_snapshot :

\#! /bin/bash

\#

\# Prepare source snapshot

\# =======================

\# Note! This script is generated from a template by Ansible

\# \-\--

bin_dir=\$(dirname \$0)

lib_dir=/opt/sbdi/lib

. \$lib_dir/log_utils

\[ \$EUID -eq 0 \] \|\| log_fatal 88 \"Root privileges reqiured\"

{% if gluster_backup_source %}

\$bin_dir/prepare_source_snapshot.gluster.sh {{
gluster_backup_source_volume }} {{
gluster_backup_source_snapshot_mount_point }}

{% endif %}

{% if lvm_backup_source %}

\$bin_dir/prepare_source_snapshot.lvm.sh {{
lvm_backup_source_volume_group }} {{ lvm_backup_source_volume }} {{
lvm_backup_source_snapshot_mount_point }}

{% endif %}

will be expanded by Ansible on the manager-1 node, that holds data to
backup on Gluster, to become:

\#! /bin/bash

\#

\# Prepare source snapshot

\# =======================

\# Note! This script is generated from a template by Ansible

\# \-\--

bin_dir=\$(dirname \$0)

lib_dir=/opt/sbdi/lib

. \$lib_dir/log_utils

\[ \$EUID -eq 0 \] \|\| log_fatal 88 \"Root privileges reqiured\"

\$bin_dir/prepare_source_snapshot.gluster.sh docker
/gluster_backupsource

and on the cassanadra-1 node, that holds local data to backup on LVM, it
will be expanded as:

\#! /bin/bash

\#

\# Prepare source snapshot

\# =======================

\# Note! This script is generated from a template by Ansible

\# \-\--

bin_dir=\$(dirname \$0)

lib_dir=/opt/sbdi/lib

. \$lib_dir/log_utils

\[ \$EUID -eq 0 \] \|\| log_fatal 88 \"Root privileges reqiured\"

\$bin_dir/prepare_source_snapshot.lvm.sh vg_docker_local lv_docker_local
/local_backupsource

6)  Finally these scripts are are "enabled" and made available to the
    backup operator by means of Linux /etc/sudoers.d (For a general
    introduction look at for instance
    <https://help.ubuntu.com/community/Sudoers> &
    <https://superuser.com/questions/869144/why-does-the-system-have-etc-sudoers-d-how-should-i-edit-it>).

To exemplify this, on manager-1, in /etc/sudoers.d , Ansible will
install the file 43-backupoperator :

\# Ensure backupoperator can transfer ssh agent when sudoing:

Defaults env_keep+=SSH_AUTH_SOCK

\# Commands performed with sudo by backupoperator at a backup-source:

Cmnd_Alias BOP_SRC_SNAP = /opt/sbdi/backup/bin/prepare_source_snapshot

Cmnd_Alias BOP_SRC_SYNC = /opt/sbdi/backup/bin/perform_rsync

Cmnd_Alias BOP_SRC_RM_SNAP = /opt/sbdi/backup/bin/remove_source_snapshot

Cmnd_Alias BOP_SRC_ALL = BOP_SRC_SNAP, BOP_SRC_SYNC, BOP_SRC_RM_SNAP,
/usr/bin/rsync

backupoperator ALL=(ALL) NOPASSWD: BOP_SRC_ALL

This will enable the backup operator on the backup director node to
(parallel) ssh into all backup sources (including manager-1) and do sudo
/opt/sbdi/backup/bin/prepare_source_snapshot as indicated by the
following extract of the /opt/sbdi/backup/bin/perform_backup script:

\...

parallel-ssh -l backupoperator -i -H \"\${BACKUP_SOURCE_HOSTS}\" \'sudo
/opt/sbdi/backup/bin/prepare_source_snapshot\'

\...

7)  There is only one RSA ssh private key, stored on the, backup
    director node that is used by the backup and restore functions. As
    explained above this key and the ssh agent is transferred by ssh
    during backup and restore operations. This design has been
    implimented in order to make it impossible for any other node than
    the backup director to initiate and run platform wide backup or
    restore operations.

8)  The RSA key and all scripts with hardcoded configuration may always
    be regenerated by Ansible. The ansible playbook may be run as may
    times as desired it will (if correct) generate and distribute a new
    RSA key and make sure that the backup and restore system is attuned
    to the current Inventory. This is to ensure that no manual (possibly
    error prone) installation and configuration is needed.

### Remaining security issues to consider

As explained above all backup and restore operations are supposed to be
based on "capsuled" scripts. Currently this is not 100% since the
restore_backup_snapshot script that resides on the backup target node
includes the following invokation of rsync over ssh in order to restore
backup data:

...

/usr/bin/rsync -a -e /usr/bin/ssh \--rsync-path=\"/usr/bin/sudo
/usr/bin/rsync\" \\

\$dry_run \$verbose \$rsync_flags \\

/backup/snapshot/\${backup_name}/ \--delete-after
backupoperator@\${remote_dest}:\${backup_source_dir}

\...

This is the reason that on all backup source nodes we need to have an
entry in sudoers that allows backup operator to do sudo rsync, like in:

Cmnd_Alias BOP_SRC_ALL = BOP_SRC_SNAP, BOP_SRC_SYNC, BOP_SRC_RM_SNAP,
/usr/bin/rsync

This is clearly an exception to the rule since rsync is a very powerful
tool. It remains to encapsulate rsync. This can most likely be done (and
it is probably a good idea to do so) but this is a notably tricky task
possibly best explained by the use of \--rsync-path=\"/usr/bin/sudo
/usr/bin/rsync\".All in all this solution enable us to do ssh (part of
rsync) not as root but as backup operator while still allowing rsync to
have needed (root) power in order to restore data. Doing ssh as root,
which is the other alternative, is a much bigger vulnerability than
having rsync in /etc*/*sudoers.

There is also a corresponding entry in /etc/sudoers.d/42-backupoperator
that allows sudo rsync that is needed for the taking of backup:

Cmnd_Alias BOP_TRG_ALL = BOP_TRG_SNAP, BOP_TRG_ACT_L\_SNAP,
BOP_TRG_ACT_SNAP, BOP_TRG_DEACT_SNAP, BOP_TRG_REST_SNAP, /usr/bin/rsync

Since this privilege to do sudo rsync is limited to only the backup
target (that is supposed to have off site data replication) it seems
less risky than enabling sudo rsync on all backup source nodes.

## Docker Swarm integration

\< Explain the paus/resume and swarm service control functionality and
how it is used to ensure data integrity and consistency\>

## Dependencies

\<List all dependencies and requirements\>

## Ansible playbook integration

\<Explain the Ansible roles involved in setting up the backup system
where they are found and how the do that.\>

The backup system is installed and managed by Ansible
(https://docs.ansible.com/ansible/latest/).

The playbook is idempotent so the following command will install and, in
case the deployment is changed it will reconfigure backup accordingly:

ansible-playbook backup.yml

The playbook runs basically five steps:

1\. sets up backup functionality and backup operator user on the backup
director virtual machine

2\. sets up a backup operator user on all other hosts involved in the
backup, i.e. the backup target node and the various backup source nodes.

3\. sets up backup functionality on backup target(s) virtual machines

4\. enables the backup operator user to control docker swarm when needed

5\. sets up backup functionality on all backup source nodes

### 1. The backup director virtual machine

In the Ansible inventory
(<https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html#intro-inventory>)
we must define which virtual machine/node that is designated as backup
director:

\[backup_director\]

backup-director

Any virtual machine in the deployment should be able to serve as backup
director but it is recommended (and only tested) with a designated
machine with very little CPU and RAM, like in:

\[servers\]

\...

backup-director nbr=91 flavor=ssc.tiny

The tasks involved in setting up the backup director is found in role:

ansible/roles/backup/director

The task of this rule will ensure a backup operator user with ***an
always new ssh key\
***and .ssh/known_hosts file to ensure scripted ssh operation.

The task also installs parallel SSH (pssh), sets up environment
variables and installs the following primary operations scripts:

perform_backup

restore_latest_backup

restore_backup

stop_docker

start_docker

pause_containers

unpause_containers

list_backups

The scripts are all well documented code and their operation is as
inferred by their names.

One thing worth pointing out however is that the scripts are Ansible
templates. When installed by the playbook the various hosts, backup
target, backup sources etc are hard coded into the scripts. This is
intentional. The scripts may not be altered, due to access rights and
they may not be run with arguments. If the setup of the deployment
platform changes the backup playbook needs to be run in order to update
these scripts.

Please also note the file ansible/roles/backup/director/vars/main.yml
defines all hosts involved in the backup based on the inventory.

### 2. Backup operator user

The task ansible/roles/backup/directed sets up a backup operator, with
the same gid and uid as on the backup director node, on all the hosts
involved in the backup, i.e. the backup target node and the various
backup source nodes.

The task also ensures the backup operator on backup target may use
passwordless ssh to access the directed nodes by means of adding the
backup operator public key to authorized_key.

The backup operator as such is entirely unprivileged. The ssh key of the
backup operator resides only in one copy on the backup director node. If
the key is compromised it may be regenerated by running the backup.yml
playbook.

The operations that may be run by the backup operator is defined by
sudoers configuarion files also generated by the backup.yml playbook.

In order to run backup operations one must log into the backup director
node an su to the backup operator user. However since the backup
operator does not have a password one must have root access to the
system in order to perform backup operations.

### 3. The backup target node

\...

### 4. Docker swarm control

\...

### 5. The backup source nodes

\...\
\
\<Explain the parameters in the inventory that affects the backup and
restore system\>

\<Explain how the backup and restore system is maintained i.e.
reinstalled by the Ansibel playbook in case of system changes\>

# Operations reference

In order to take a backup the administrator first needs to log into the
backup director node and become backup operator. On the uat system this
translates to:

### To access backup operations

\$ ssh -J uat-access-1 uat-backup-director

\$ sudo su -- backupoperator

Backup operation commands are found in the /opt/sbdi/backup/bin/
directory

### To list existing backup operations

\$ cd /opt/sbdi/backup/bin/

/opt/sbdi/backup/bin\$ ls -1

list_backups

pause_containers

perform_backup

restore_backup

restore_latest_backup

start_docker

stop_docker

unpause_containers

### To run a backup

/opt/sbdi/backup/bin\$ ./perform_backup\
...

###  To list existing backups

/opt/sbdi/backup/bin\$ ./list_backups

20220906_082043

20220903_003826\
\...

Backups are listed by a date and time string. Such a string is also the
***backup identifier*** .

### To restore backups

In order to restore a backup the docker services on all nodes must be
shut down

/opt/sbdi/backup/bin\$ ./stop_docker

When all docker services have been shutdown we may restore a specific
backup by identifier like:

/opt/sbdi/backup/bin\$ ./restore_backup 20220903_003826

We may also restore the last backup and then no backup identifier is
needed:

/opt/sbdi/backup/bin\$ ./restore_latest_backup

Finally when the backup has been successfully restored all docker
services in the platform must be restarted:

/opt/sbdi/backup/bin\$ ./start_docker

### Pausing and unpausing docker containers

When a backup is performed just before file system snapshots are taken
the backup system pauses all containers. That is to ensure that local
data on the various docker swarm nodes are in sync. After the snapshot
has been taken all containers are unpaused. This is a safety precaution
and will stop all operations for only a few seconds.

Pausing and unpausing is handled by the perform backup command
automatically and there is no need for the backup operator to use them
explicitly.

The pause and unpaus commands are however available to the backup
operator explicitly also since they might be handy operations for
various reasons. Remember to use them with caution since they will
freeze all SBDI operations and may thus have any number of spin off
effects.

## Automating backup 

It is possible to automate the backup procedure with, for instance,
crontab (<https://www.adminschoice.com/crontab-quick-reference>).

Keep in mind if crontab is used to make sure that:

1.  The perform backup command is run by cron as backup operator user

2.  The backup operator environment variable DOCKER_HOSTS is set. Please
    note that this environment variable is set by Ansible in the
    /home/backupoperator/.bashrc file.

Note of caution: Currently the backup system has not been "battle
tested". It is suggested that automated backups are introduced when
there are supervision implemented, i.e. Nagios, that monitors success.
Also it is suggested that manual backups are performed for a suitable
time in order to ensure that it works without "hiccups".

# Way forward -- remaining issues

The SBDI deployment platform is currently not tested and operational
some features of the backup systems are (because of lack of time) not
yet in place.

This section will go through all remaining issues and provide some
insight into how to complete them and what to look for in the future.

# Overview reference

\<Here goes the pictures that summarize the above and thus may serve as
a map and reference that brings together the overall understanding of
the system. It might be placed at the front but without an understanding
of the design principles (described above) it will be just one of those
over complicated diagrams that cause more confusion than they bring
clarity\... \>

TODO: Do not forget that there should be links to each and every one of
the technologies that we talk about above.
