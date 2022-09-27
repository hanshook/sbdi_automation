Backup and Restore System

[]{#anchor}Short Summary
========================

The Backup and Restore system is part of the SBDI deployment platform.
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

A key factor important to understanding the Backup and Restore system is
that it is designed from the ground up to be a part of the SBDI
deployment platform. It is deployed by an Ansible playbook based on the
same inventory information that is used to deploy the platform itself.
Consequently very little configuration specific to the Backup and
Restore system is needed. Also the SBDI deployment platform is designed
from the beginning to work optimally with the backup system. This
applies to such things as name conventions, where data is placed,
network setup, which file systems are used etc.

Also the Backup and Restore system is designed making full use of the
fact that SBDI is dockerized. For instance the system uses docker pause
and resume in order to ensure the integrity and consistency of backup
data. Also the system will manage the docker swarm when backups are
restored in order to ensure the integrity and consistency of backup
data.

[]{#anchor-1}Intended use of this document
==========================================

The intended use of this document is that a reasonably experienced Linux
systems administrator should be able to fully understand how the Backup
and Restore system is designed, installed, maintained and how it may be
operated and further developed.

[]{#anchor-2}Status 
====================

As of September 2022 primary services are fully implemented and tested
(with sample data) and ready for automated use.\
Secondary services, except off site replication, are implemented, not
fully tested and not automated. In order to use those functions
initiated manual operations are required. Off site replication is based
on ZFS replication and thus implemented but, as of now, needs to be
configured and setup manually.

[]{#anchor-3}Design principles
==============================

This section is intended to provide knowledge about how the Backup and
Restore system works and why as well as on how to maintain it.\
Since the Backup and Restore system has not been fully deployed also
possible future problems and how to resolve them are addressed.

[]{#anchor-4}Terms used
-----------------------

A backup or a restore of a backup is initiated and controlled by a
*Backup Director Node*.

Parties involved in the backup holding data are referred to as *Backup
Source Nodes.*

Backup Source Nodes may either hold global data stored on Gluster
(explained below) or hold local data stored on LVM (also explained
below).

The objective of a backup is to transfer/synchronize and store all data
that is to be backed up from the Backup Source Nodes to a *Backup Target
Node*. The data backed up should represent one instance in time, i.e.
the data on the Backup Source Nodes should be somehow “frozen” at the
same time and then transferred to the Backup Target Node. If the data
saved in a backup is a complete representation from one instance in time
it may safely and successfully be restored and operations may continue,
as if nothing had ever happened, since the point in time when the backup
was taken.

The Backup Target Node holds a number of backups, that represent the
sate of the system at the time the backups where taken. Backups stored
on the Backup Target Node are stored incrementally, i.e. each backup are
not stored completely and separately but rather the change from the last
backup is stored. This procedure is essential in order to save space.
Furthermore data stored on the Backup Target Node is compressed to save
space. In practice we can hold dozens of backups on a disk space
probably less than what is used by the running system. Backups on the
Backup Target Node are also stored in such a way that any one single
backup may be accessed and restored to the running system. How this is
implemented is covered below.

The final node in a complete Backup and Restore system is the *Remote
Backup Server*. The Remote Backup Server is running at a different
geographical location so that its data is kept safe even if the Backup
Target Node is totally destroyed. The Remote Backup Server will hold
exactly the same data as the Backup Target Node, i.e. data is
synchronized/replicated. Since the Remote Backup Server is remote, data
replication from the Backup Target Node is not instant but rather
synchronized/replicated as an ongoing process.

[]{#anchor-5}The phases of a backup
-----------------------------------

1.  The Backup Director will order Docker to pause all docker containers
    in the system
2.  The Backup Director will order, in parallel, all Backup Source Nodes
    to create snapshots (frozen images) of data to backup.
3.  The Backup Director will order Docker to unpause all docker
    containers in the system. This stage will be reached in a matter of
    seconds and from now on systems operations may go on uninterrupted.
    Users of the system will (hopefully) have experienced only a short
    delay of a few seconds.
4.  The Backup Director will order all Backup Source Nodes in sequence
    (one at a time) to synchronize there snapshot of data to the Backup
    Target. This is the time and resource consuming stage of the backup.
    It may continue for hours but it does not interfere with the normal
    systems operations.
5.  When the synchronization is completed the Backup Director will order
    the Backup Target Node to save all data (representing the complete
    backup) as a tagged complete backup, i.e. a ZFS snapshot (as
    explained below).
6.  Finally the Backup Director will order, in parallel, all Backup
    Source Nodes to remove the snapshots (frozen images) of data.

[]{#anchor-6}The backup restore
-------------------------------

Before the restore of a backup all operations in the system must be
terminated.

The first step is to stop all Docker services system wide. There is
command to do that available on the Backup Director.

The restore operation is conducted by the Backup Director. It will:

1.  Order the Backup Target to activate the desired backup, i.e. mount
    it locally.
2.  Order the Backup Target to sequentially restore the data of each
    Backup Source Node
3.  Finally the Backup Director will order the Backup Target to
    deactivate the desired backup.

When a backup has been restored all Docker services system wide should
be restarted. There is command to do that available on the Backup
Director. When Docker services have been restarted the system state
should then ideally have been restored to that of the backup.

[]{#anchor-7}Gluster and gluster snapshots
------------------------------------------

The deployment platform uses GlusterFS
(https://docs.gluster.org/en/latest/) to store docker swarm images.\
There currently exists only one Gluster volume called *docker* that is
provided by the nodes *manager-\[1..3\]*. This gluster volume is mounted
at */docker* on all host nodes of the docker swarm. In the filesystem
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

During backup a snapshot of the Gluster volume is taken on the
*manager-1* node and mounted at */gluster\_backupsource* after rsyncing
that filesystem to the backup target the snapshot is removed.

It is worth pointing out that during the time of the rsync the Gluster
snapshot will gradually take up more and more space as the SBDI system
performs its task (backup does not interrupt operations). It is
essential to make sure there is enough space on the thinly provisioned
LVM backing device to support that growth. In essence it might not be a
good idea to import or process a lot of new data into the system or make
big changes during the rsync phase of the backup.

[]{#anchor-8}Logical volume based local storage
-----------------------------------------------

The deployment platform uses LVM to store Cassandra and Solr data
locally. The backup system makes use of that in order to backup that
data.

The local data for Cassandra and Solr is kept on a logical volume called
*lv\_docker\_local* that is mounted at */docker\_local*.

During a backup the backup system will, using parallel ssh, take
snapshots of the *lv\_docker\_local* volumes on all Cassandra and Solr
nodes and mount the snapshots at */local\_backupsource*.

After using rsync to synchronize the data under */local\_backupsource*
to the backup target host the snapshots are unmounted and removed.

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

[]{#anchor-9}ZFS Backup Target
------------------------------

It is easy to confuse the term “backup target”. One might think of it as
either the data that we intend to backup (probably the most natural
association?) or the result of the backup procedure, i.e. the backup
itself. We use the second alternative and thus with “backup target” we
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

ZFS snapshots[^1] are used in order to earmark individual backups.

### []{#anchor-10}Possible week points

Backup and Restore system has not been tested with full SBDI data
volumes. If it happens backups tend to be very it might be worth
considering that:

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
enough performance at lest for normal incremental dayly backups. With a
full scale first backup of \~ 5TB+ however things become more
uncertain.\

An alternative to ZFS might be btrfs
(<https://btrfs.wiki.kernel.org/index.php/Main_Page>) but there is no
reason at this point to expect better performance. Btrfs is mentioned
here only since it provides a similar functionality as ZFS.\

**Important:** In case of performance issues other possible bottlenecks,
other than ZFS, must also be considered like rsync and network
performance.

[]{#anchor-11}Rsync
-------------------

Backups make use of rsync in order to transfer data to the backup target
server (<https://en.wikipedia.org/wiki/Rsync>). On paper rsync is
absolutely ideal for the intended use since it only transfers those
files that has been changed which in normal SBDI case on a day to day
basis is merely a tiny fraction of all files.

SBDI is normally a “read only” system since big changes occurs only when
new data sets are imported. This should make incremental daily backups
based on rsync very fast.

**Important**: Since SBDI data consists of a very large quantity of
small files it is important to test performance and consider tuning when
the SBDI system is fully loaded with data.

### []{#anchor-12}Possible problems with performance

Since we are running rsync over ssh all communication is encrypted. This
is a good candidate bottleneck for performance. Following is just a
couple of suggestions that may be tried if backups turns out to takes
days in stead of hours:

1.  Use a lighter encryption algorithm, i.e. like *-e "ssh -c arcfour".*
2.  Do not use any encryption - for instance with HPN-SSH
    (<https://www.psc.edu/hpn-ssh-home/>). This should be acceptable,
    w.r.t. security, since the internal network of the SBDI deployment
    platform is well protected.
3.  Consider removing *atime[^2]* from snapshot file systems mounts.
    Since *atime* might impose a lot of network traffic in the
    underlying OpenStack network file system layers.
4.  Consider using rsync with --whole-file option or possibly with
    compression -z.
5.  Consider using jumbo frames[^3], i.e. MTU 9000 networking.

It is important to realize that **accepting terrible performance should
not be necessary**. The basic design should be able to perform well.
Tuning it to swiftness however might involve a lot of systematic work.

[]{#anchor-13}SSH and parallel ssh 
-----------------------------------

The Backup and Restore system entirely relies on ssh in order to execute
its distributed task.

When taking and removing snapshots parallel ssh is used since all
snapshots not only can but ***must**** ****b****e*** taken at the same
instance in time in order to ensure the consistency of the backup. If
that is not the case, when backups are restored, internal services in
the system might be out of sync.

When syncing backup data from the snapshots to the backup target server
these rsync tasks are performed in sequence. This is by design since it
is reasonable to assume that running several rsync tasks in parallel
against one backup target server will most likely slow down operations.

Furthermore the rsync phase does not have to be performed in a hurry
since the data to backup is kept safe on the snapshots.

### []{#anchor-14}Introduce more parallelism to speed up backups

In case backups turn out to be to slow to be practical and tuning, as
suggested in other sections of this paper, turns out to not solve the
issue there always remains the option of introducing more than one
backup target. The general idea here is that the backup system works
precisely as now but that the backup is divided up, for instance one
backup target node per Solar and Cassandra nod.

Although it is very possible to achieve this parallelism it will
complicate the design. It is mentioned here just to indicate a possible
solution if the problem with sequential rsync turns out to be a major
one.

[]{#anchor-15}The backup structure 
-----------------------------------

The structure of the backup is intentionally kept simple. On the Backup
Target the current (last) backup is mounted at */backup/current* as
illustrated by:

/backup/current\# ls -1

cassandra-1@+docker\_local

cassandra-2@+docker\_local

cassandra-3@+docker\_local

cassandra-4@+docker\_local

manager-1@+docker

solr-1@+docker\_local

solr-2@+docker\_local

solr-3@+docker\_local

solr-4@+docker\_local

Under each of these directories we will find the files and directories
as they where, for instance at /docker\_local on host cassandra-1, at
the time of the last backup.\
(Note that ‘/’ may not be used in filenames and has been replaced by
‘+’. Also the ‘*@+*’ separator are made up of posix filesystem
characters that and extremely unlikely to occur in any host name.)

**Important:** Do not provide virtual machines in an SBDI deployment
platform with names including ‘@+’ since it will break the backup
functionality.

[]{#anchor-16}Backup portability
--------------------------------

Note that in the above section on backup structure host names like
cassandra-1 and **instead of** uat-cassandra-1 or prod-cassandra-1 are
used. In the SBDI deployment platform, as specified in the inventory
like

\# Deployment specific vars

\# ========================

\[all:vars\]

deployment\_prefix=uat

...

*uat* and *prod* are referred to as a *deployment prefix*. This concept
is made use of in order to be able to deploy SBDI in such a way that
there are nothing that is different other than this host name prefix
between for instance, test, staging (uat) and production (prod)
deployments.

In the Backup and Restore system this design principle is made use of in
such a way that it is possible to restore a production backup in staging
deployment without transforming any data.

### []{#anchor-17}Procedure to restore production data in staging

In order to restore production data in staging do the following:

1.  Shutdown both staging and production backup target nodes. They will
    be called *uat-backup-target* and prod-backup-target respectively.
2.  Unattach the staging backup data volume from the staging backup
    target node. It is called *uat-backup-target-volume\_backup*.
3.  Unattach the production backup data volume from the production
    backup target node. It is called
    *prod-backup-target-volume\_backup*.
4.  Attach the production backup data volume to the staging backup
    target node.
5.  Start the staging backup target node
6.  Restore the the backup on the staging backup target node\

Production data will now be restored in staging.

[]{#anchor-18}Security
----------------------

The backup operator user has access to almost all machines in the system
and must have root access in order to read and restore data and system
state. In order for such a powerful system agent not to be able to bad
things in case of malfunction, incorrect setup or if it is compromised
the following patterns and principles have been followed in the design
of the Backup and Restore system:

1)  The backup operator is an unprivileged user without a password, i.e.
    it can not do general sudo “on its own” and it is not possible to
    login as backup operator as exemplified by:

\$cat /etc/passwd | grep backupoperator

backupoperator:x:1901:1901::/home/backupoperator:/bin/bash

\$cat /etc/shadow | grep backupoperator

backupoperator:!:19117:0:99999:7:::

\$cat /etc/group | grep backupoperator

backupoperator:x:1901:

1)  The privileged operations that the backup operator performs have
    (with one exception – see below) been capsuled into only a few
    scripts that needs to be run with sudo, i.e. these capsule scripts
    include the various low level commands that on their own (not
    encapsulated) may be used to do many other (potentially harmful)
    things.
2)  These scripts have no arguments or switches of functional character,
    i.e. if they do not have bugs they are not supposed to be used for
    performing any other (potentially harmful) task than their intended.
3)  Further more these scripts (if there are no bugs in the Ansible
    installation tasks!) have been given file permissions ensuring that
    they may not be modified without root access as exemplified by the
    scripts on the manger-1 node:

/opt/sbdi/backup/bin\# ls -lrth

total 48K

-rwxr-xr-x 1 root root 422 May 5 14:51 start\_docker

-rwxr-xr-x 1 root root 441 May 5 14:51 stop\_docker

-rwxr-xr-x 1 root root 617 May 5 14:51 pause\_containers

-rwxr-xr-x 1 root root 634 May 5 14:51 unpause\_containers

-rwxr-xr-x 1 root root 3.5K May 5 14:52
prepare\_source\_snapshot.gluster.sh

-rwxr-xr-x 1 root root 2.1K May 5 14:52
remove\_source\_snapshot.gluster.sh

-rwxr-xr-x 1 root root 4.1K Jul 14 12:44
prepare\_source\_snapshot.lvm.sh

-rwxr-xr-x 1 root root 2.5K Jul 14 12:44 remove\_source\_snapshot.lvm.sh

-rwxr-xr-x 1 root root 341 Sep 2 07:50 prepare\_source\_snapshot

-rwxr-xr-x 1 root root 2.0K Sep 2 07:50 perform\_rsync

-rwxr-xr-x 1 root root 341 Sep 2 07:50 remove\_source\_snapshot\
\

1)  Also these scripts are generated by the Ansible installation tasks
    in such a way that all configuration is hardcoded into the scripts,
    i.e. there are no configuration files (that may be manipulated or
    include incorrect settings).\

Thus the template script file
*ansible/roles/backup/source/templates/bin/prepare\_source\_snapshot* :

\#! /bin/bash

\#

\# Prepare source snapshot

\# =======================

\# Note! This script is generated from a template by Ansible

\# ---

bin\_dir=\$(dirname \$0)

lib\_dir=/opt/sbdi/lib

. \$lib\_dir/log\_utils

\[ \$EUID -eq 0 \] || log\_fatal 88 "Root privileges reqiured"

{% if gluster\_backup\_source %}

\$bin\_dir/prepare\_source\_snapshot.gluster.sh {{
gluster\_backup\_source\_volume }} {{
gluster\_backup\_source\_snapshot\_mount\_point }}

{% endif %}

{% if lvm\_backup\_source %}

\$bin\_dir/prepare\_source\_snapshot.lvm.sh {{
lvm\_backup\_source\_volume\_group }} {{ lvm\_backup\_source\_volume }}
{{ lvm\_backup\_source\_snapshot\_mount\_point }}

{% endif %}

will be expanded by Ansible on the manager-1 node, that holds data to
backup on Gluster, to become:

\#! /bin/bash

\#

\# Prepare source snapshot

\# =======================

\# Note! This script is generated from a template by Ansible

\# ---

bin\_dir=\$(dirname \$0)

lib\_dir=/opt/sbdi/lib

. \$lib\_dir/log\_utils

\[ \$EUID -eq 0 \] || log\_fatal 88 "Root privileges reqiured"

\$bin\_dir/prepare\_source\_snapshot.gluster.sh docker
/gluster\_backupsource

and on the cassanadra-1 node, that holds local data to backup on LVM, it
will be expanded as:

\
\#! /bin/bash

\#

\# Prepare source snapshot

\# =======================

\# Note! This script is generated from a template by Ansible

\# ---

bin\_dir=\$(dirname \$0)

lib\_dir=/opt/sbdi/lib

. \$lib\_dir/log\_utils

\[ \$EUID -eq 0 \] || log\_fatal 88 "Root privileges reqiured"

\$bin\_dir/prepare\_source\_snapshot.lvm.sh vg\_docker\_local
lv\_docker\_local /local\_backupsource

1)  Finally these scripts are are “enabled” and made available to the
    backup operator by means of Linux */etc/sudoers.d* (For a general
    introduction look at for instance
    <https://help.ubuntu.com/community/Sudoers> &
    <https://superuser.com/questions/869144/why-does-the-system-have-etc-sudoers-d-how-should-i-edit-it>).

To exemplify this, on *manager-1,* in */etc/sudoers.d* , Ansible will
install the file *43-backupoperator *:\

\# Ensure backupoperator can transfer ssh agent when sudoing:

Defaults env\_keep+=SSH\_AUTH\_SOCK

\# Commands performed with sudo by backupoperator at a backup-source:

Cmnd\_Alias BOP\_SRC\_SNAP =
/opt/sbdi/backup/bin/prepare\_source\_snapshot

Cmnd\_Alias BOP\_SRC\_SYNC = /opt/sbdi/backup/bin/perform\_rsync

Cmnd\_Alias BOP\_SRC\_RM\_SNAP =
/opt/sbdi/backup/bin/remove\_source\_snapshot

Cmnd\_Alias BOP\_SRC\_ALL = BOP\_SRC\_SNAP, BOP\_SRC\_SYNC,
BOP\_SRC\_RM\_SNAP, /usr/bin/rsync

backupoperator ALL=(ALL) NOPASSWD: BOP\_SRC\_ALL

This will enable the backup operator on the backup director node to
(parallel) ssh into all backup sources (including *manager-1*) and do
*sudo /opt/sbdi/backup/bin/prepare\_source\_snapshot* as indicated by
the following extract of the */opt/sbdi/backup/bin/perform\_backup*
script:

...

parallel-ssh -l backupoperator -i -H "\${BACKUP\_SOURCE\_HOSTS}" 'sudo
/opt/sbdi/backup/bin/prepare\_source\_snapshot'

...\

1)  There is only one RSA ssh private key, stored on the, backup
    director node that is used by the backup and restore functions. As
    explained above this key and the ssh agent is transferred by ssh
    during Backup and Restore operations. This design has been
    implemented in order to make it impossible for any other node than
    the backup director to initiate and run backup or restore
    operations.
2)  The RSA key and all scripts with hard coded configuration may always
    be regenerated by Ansible. The ansible playbook may be run as may
    times as desired it will (if correct) generate and distribute a new
    RSA key and make sure that the Backup and Restore system is attuned
    to the current Inventory. This is to ensure that no manual (possibly
    error prone) installation and configuration is needed. \

### []{#anchor-19}Remaining security issues to consider

\
As explained above all Backup and Restore operations are supposed to be
based on “capsuled” scripts. Currently this is not 100% since the
*restore\_backup\_snapshot* script that resides on the backup target
node includes the following invokation of rsync over ssh in order to
restore backup data:

…

/usr/bin/rsync -a -e /usr/bin/ssh --rsync-path="/usr/bin/sudo
/usr/bin/rsync" \\

 \$dry\_run \$verbose \$rsync\_flags \\

 /backup/snapshot/\${backup\_name}/ --delete-after
backupoperator@\${remote\_dest}:\${backup\_source\_dir}

...

This is the reason that on all backup source nodes we need to have an
entry in sudoers that allows backup operator to do sudo rsync, like in:

Cmnd\_Alias BOP\_SRC\_ALL = BOP\_SRC\_SNAP, BOP\_SRC\_SYNC,
BOP\_SRC\_RM\_SNAP, /usr/bin/rsync

This is clearly an exception to the rule since rsync is a very powerful
tool. It remains to encapsulate rsync. This can most likely be done (and
it is probably a good idea to do so) but this is a notably tricky task
possibly best explained by the use of *--rsync-path="/usr/bin/sudo
/usr/bin/rsync".*All in all this solution enable us to do ssh (part of
rsync) not as root but as backup operator while still allowing rsync to
have needed (root) power in order to restore data. Doing ssh as root,
which is the other alternative, is a much bigger vulnerability than
having rsync in /*etc/sudoers*.

There is also a corresponding entry in
*/etc/sudoers.d/42-backupoperator* that allows sudo rsync that is needed
for the taking of backup:

Cmnd\_Alias BOP\_TRG\_ALL = BOP\_TRG\_SNAP, BOP\_TRG\_ACT\_L\_SNAP,
BOP\_TRG\_ACT\_SNAP, BOP\_TRG\_DEACT\_SNAP, BOP\_TRG\_REST\_SNAP,
/usr/bin/rsync

Since this privilege to do sudo rsync is limited to only the backup
target it is deemed less risky than enabling sudo rsync on all backup
source nodes.

[]{#anchor-20}Docker Swarm integration
--------------------------------------

To implement a pause or unpause of all docker containers the Backup
Director will use parallel ssh to execute the following commands on each
host running docker (either in swarm or standalone mode):

CONTAINERS="\$(docker container ls --format '{{ .ID }}')"

docker container pause \$CONTAINERS

or

CONTAINERS="\$(docker container ls --format '{{ .ID }}')"

docker container unpause \$CONTAINERS

In order to start or stop docker services Backup Director will use
parallel ssh to execute the following command on each host running
docker (either in swarm or standalone mode):

systemctl start docker

or

systemctl stop docker.socket

The latter command is necessary since just stop docker leaves docker
services running.

[]{#anchor-21}Dependencies
--------------------------

The Backup and Restore system is installed as an integral part of the
SBDI deployment platform.

It is assumed that all the parts of the SBDI deployment platform is
installed. That is Ansible playbooks corresponding to step 1 through 10
(refer to automation/ansible/README.md) must have been run.

### []{#anchor-22}Logging and supervision

All Backup and Restore operations uses the */opt/sbdi/lib/log\_utils*
package to log progress and errors. */opt/sbdi/lib/log\_utils* uses a
uniform log format that will (although backup operations are distributed
onto many different hosts) make it possible to collect syslog streams
form all SBDI nodes and filter them in a central logging server. Thus it
will be possible to monitor and analyze logging operations as integrated
operations. Also in this way it will, for instance by means of a Nagios
“probe” script, be possible to issue alerts in case backups are not
working or taking to long etc.

\
Note: Although SBDI deployment platform is designed for centralized
logging this is not implemented yet.

[]{#anchor-23}Ansible playbook integration
------------------------------------------

The backup system is installed and managed by Ansible
(https://docs.ansible.com/ansible/latest/).

**Important:** The playbook is idempotent so the following command will
install and, *in case the deployment is changed* it will reconfigure
backup accordingly:

ansible-playbook backup.yml

The playbook runs basically five steps:

1\. sets up backup functionality and backup operator user on the backup
director virtual machine

2\. sets up a backup operator user on all other hosts involved in the
backup, i.e. the backup target node and the various backup source nodes.

3\. sets up backup functionality on backup target(s) virtual machines

4\. enables the backup operator user to control docker swarm when needed

5\. sets up backup functionality on all backup source nodes

**Important:** Do not reconfigure or change the Backup and Restore
system directly on the deployed hosts – use the Playbook. Files managed
by Ansible might otherwise for example get out of sync.

### []{#anchor-24}1. The backup director virtual machine

In the Ansible inventory
(<https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html#intro-inventory>)
we must define which virtual machine/node that is designated as backup
director:

\[backup\_director\]

backup-director

Any virtual machine in the deployment should be able to serve as backup
director but it is recommended (and only tested) with a designated
machine with very little CPU and RAM, like in:

\[servers\]

...

backup-director nbr=91 flavor=ssc.tiny

The tasks involved in setting up the backup director is found in role:

ansible/roles/backup/director

The task of this rule will ensure a backup operator user with ***an
always new ssh key\
***and *.ssh/known\_hosts* file to ensure scripted ssh operation.

The task also installs parallel SSH (pssh), sets up environment
variables and installs the following primary operations scripts:

\
 perform\_backup

 restore\_latest\_backup

 restore\_backup

 stop\_docker

 start\_docker

 pause\_containers

 unpause\_containers

 list\_backups

The scripts are all well documented code and their operation is as
inferred by their names.

One thing worth pointing out however is that the scripts are Ansible
templates. When installed by the playbook the various hosts, backup
target, backup sources etc are hard coded into the scripts. This is
intentional. The scripts may not be altered, due to access rights and
they may not be run with arguments. If the setup of the deployment
platform changes the backup playbook needs to be run in order to update
these scripts.

Please also note the file *ansible/roles/backup/director/vars/main.yml
*defines all hosts involved in the backup based on the inventory.

### []{#anchor-25}2. Backup operator user

The task *ansible/roles/backup/directed* sets up a backup operator, with
the same gid and uid as on the backup director node, on all the hosts
involved in the backup, i.e. the backup target node and the various
backup source nodes.

The task also ensures that the backup operator on backup target may use
passwordless ssh to access the directed nodes by means of adding the
backup operator public key to authorized\_key.

The backup operator as such is entirely unprivileged. The ssh key of the
backup operator resides only in one copy on the backup director node. If
the key is compromised it may be regenerated by running the *backup.yml*
playbook.

The operations that may be run by the backup operator, with root
privileges, is defined by sudoers configuration files also generated by
the *backup.yml* playbook.

In order to run backup operations one must log into the backup director
node an su to the backup operator user. However since the backup
operator does not have a password one must have root access to the
system in order to perform backup operations.

### []{#anchor-26}3. The backup target node

The task *ansible/roles/backup/target* is well annotaded. Most
importantly it installs ZFS and sets up a ZFS pool (if needed) and makes
sure there is a /backup mount point with a ZFS file system mounted.

OIn order for that to work there must be a *backup\_data\_device*
present.\
The *backup\_data\_device* is currently configured in the file
*ansible/groups\_vars/backup\_targets*

Its current default value, i.e.

backup\_data\_device: /dev/vdb

works when using network provided data volumes (as we currently do) but
may have to be adjusted in other setups.

Also note the following setting in the inventory file:

\[servers\]

...

backup-target nbr=92 flavor=ssc.medium.highmem volume\_backup=1500

The *volume\_backup* variable is used in the playbook

automation/ansible/deploy.yml

and its subordinate role

automation/ansible/roles/deploy/storage\_volumes/tasks/main.yml

where it will be used to attach an OpenStack disk volume, with correct
size, to the Backup Target Node.

Pleas note that due to limitations in OpenStack it is not possible to
resize a mounted volume. This makes it complicated to write an
idempotent Anisble Playbook to automatically adjust the size of data
volumes to specified values. In short the Backup Target Node data volume
is setup once by Ansibel but must be manually resized if needed occurs.

In order to resize the backup disk space on Backup Target Node the
Backup Target Node first have to be shut down and the volume resized in
OpenStack GUI or by OpenStack commands:\
\
After restarting the Backup Target Node the device */dev/vdb* will have
increased:

\# parted -l

Model: Virtio Block Device (virtblk)

Disk /dev/vdb: **&lt;larger value than 1611GB here&gt;**

Sector size (logical/physical): 512B/512B

Partition Table: gpt

Disk Flags:

Number Start End Size File system Name Flags

 1 1049kB 1611GB 1611GB zfs zfs-f29da1940c667ec6

 9 1611GB 1611GB 8389kB

The problem here is that partion 9 created by ZFS is blocking a

*parted /dev/sdb resizepart 1 100%*

****

**that we would like to issue in order to make it possible for ZFS to
take advantage of the extra space **now available on */dev/vdb*. **\
This is a consequence of not providing ZFS with disks to manage as it is
designed **to have**. **W**e may not do that, since we are running on
OpenStack, **and thus we have to work around this problem.**

**In order to avoid this problem it is **by far easiest to allocate
**enough disk space from the beginning when the Backup Target is
deployed**[^4]**.\
\
If expanding space is necessary this is possible. There mater is
discussed in for instance
**[**https://serverfault.com/questions/946055/increase-the-zfs-partition-to-use-the-entire-disk**](https://serverfault.com/questions/946055/increase-the-zfs-partition-to-use-the-entire-disk)**.\
\
It **might work just to remove the 9’th partion and let parted resize
the disk. In case production data backups are stored on the disk it
might be vise to try **this out and develop a **resizing a **procedure
in a test deployment **first**. Also with off site replication in place
the risks associated with destroying data is **lower**.**

### []{#anchor-27}4. Docker swarm control

The task *ansible/roles/backup/docker\_control *is simple and well
annotated. It installs the scripts involved for docker daemon control
(*start\_docker, stop\_docker, paus\_containers, unpause\_containers*)
and configures sudoers rights on all nodes running docker.

Please note that there are scripts with the same name on the Backup
Director Node[^5]. These “director scripts” that coordinate starting,
stopping etc in the system must not be confused with the once installed
on the nodes running docker.

### []{#anchor-28}5. The backup source nodes

The task *ansible/roles/backup/directed* basically sets up a backup
operator user on all nodes that are controlled by the Backup Director.

The task *ansible/roles/backup/source* does:

Ensures mount points for snapshots (either LVM or Gluster)

Installs scripts for creating and removing snapshots (either LVM or
Gluster)

Enables suoders rights in order to allow the backup operator sudo rights
to these scripts

Ensures root ssh access to backup target, i.e. updates
/root/.ssh/known\_hosts. This might seem tricky but is necessary because
rsync does the reading of backup data as root but it will ssh as backup
operator user.

After some refactoring it was decided to make backup sources explicit in
the inventory. Of course it is possible to deduce this information but
explicit clarity was decided a better option. Consequently now the
backup sources must have a section of their own:

\
\[backup\_sources\]

manager-1 gluster\_backup\_source=True lvm\_backup\_source=False
backup\_snapshot\_storage=0

cassandra-1 gluster\_backup\_source=False lvm\_backup\_source=True
backup\_snapshot\_storage=20

cassandra-2 gluster\_backup\_source=False lvm\_backup\_source=True
backup\_snapshot\_storage=20

cassandra-3 gluster\_backup\_source=False lvm\_backup\_source=True
backup\_snapshot\_storage=20

cassandra-4 gluster\_backup\_source=False lvm\_backup\_source=True
backup\_snapshot\_storage=20

solr-1 gluster\_backup\_source=False lvm\_backup\_source=True
backup\_snapshot\_storage=20

solr-2 gluster\_backup\_source=False lvm\_backup\_source=True
backup\_snapshot\_storage=20

solr-3 gluster\_backup\_source=False lvm\_backup\_source=True
backup\_snapshot\_storage=20

solr-4 gluster\_backup\_source=False lvm\_backup\_source=True
backup\_snapshot\_storage=20

As noted this is very explicit and there is room for improvement but as
for now the variables *gluster\_backup\_source, lvm\_backup\_source
*and* backup\_snapshot\_storage* needs to be explicitly specified.

*gluster\_backup\_source* and *lvm\_backup\_source* may currently not be
both true.\
backup\_snapshot\_storage is irrelevant for gluster volumes and should
be set to 0

*backup\_snapshot\_storage* for LVM local storage nodes is used by the
playbook

automation/ansible/deploy.yml

in order to ensure there is enough space for the snapshots on the
volumes attached to the nodes.

**Please note** that at present how big the snapshots will be during
normal operation is unknown and dependent on usage of the system
currently not possible to measure. Therefor it is strongly reccomended
that during a stress test of the system a backup is also run and the LVM
snapshot sizes are closely monitored. Alternatively assign a very large
upper limit, i.e. not 20GB but rather 100GB.

[]{#anchor-29}Operations reference
==================================

In order to take a backup the administrator first needs to log into the
backup director node and become backup operator. On the uat system this
translates to:

### []{#anchor-30}To access backup operations

\
\$ ssh -J uat-access-1 uat-backup-director

\$ sudo su – backupoperator

Backup operation commands are found in the */opt/sbdi/backup/bin/*
directory

**Important:** Backup operations may take a long time and if interrupted
complicated manual “cleaning up” might be necessary. In order to
minimize the risk of that happening it is recommended to run the
following operations in a GNU Screen shell, or similar,
(<https://www.gnu.org/software/screen/>) in order to be able to detach
the shell without interrupting unfinished work.

### []{#anchor-31}To list existing backup operations

\$ cd /opt/sbdi/backup/bin/

/opt/sbdi/backup/bin\$ ls -1

list\_backups

pause\_containers

perform\_backup

restore\_backup

restore\_latest\_backup

start\_docker

stop\_docker

unpause\_containers\
\

### []{#anchor-32}To run a backup

\
/opt/sbdi/backup/bin\$ ./perform\_backup\
…

### []{#anchor-33}\
To list existing backups

/opt/sbdi/backup/bin\$ ./list\_backups

20220906\_082043

20220903\_003826\
...

\
Backups are listed by a date and time string. Such a string is also the
***backup identifier*** .\

### []{#anchor-34}To restore backups

In order to restore a backup the docker services on all nodes must be
shut down

/opt/sbdi/backup/bin\$ ./stop\_docker

When all docker services have been shutdown we may restore a specific
backup by identifier like:

/opt/sbdi/backup/bin\$ ./restore\_backup 20220903\_003826

We may also restore the last backup and then no backup identifier is
needed:

/opt/sbdi/backup/bin\$ ./restore\_latest\_backup

Finally when the backup has been successfully restored all docker
services in the platform must be restarted:

/opt/sbdi/backup/bin\$ ./start\_docker\

### []{#anchor-35}Pausing and unpausing docker containers

During a backup operation just before file system snapshots are taken
the backup system pauses all containers. That is to ensure that local
data on the various docker swarm nodes are in sync. After the snapshot
has been taken all containers are unpaused. This is a safety precaution
and will stop all operations for a few seconds.

Pausing and unpausing is handled by the perform backup command
automatically and there is no need for the backup operator to use them
explicitly.

The pause and unpaus commands are however also made available to the
backup operator explicitly since they might be handy operations for
various reasons. Remember to use them with caution since they will
freeze all SBDI operations and may thus have any number of spin off
effects.

[]{#anchor-36}Automating backup 
--------------------------------

It is possible to automate the backup procedure with, for instance,
crontab (<https://www.adminschoice.com/crontab-quick-reference>).

Keep in mind if crontab is used to make sure that:

1.  The perform backup command is run by cron as a backup operator user
2.  The backup operator environment variable *DOCKER\_HOSTS* is set.
    This environment variable is set by Ansible in the
    */home/backupoperator/.bashrc* file.

Note of caution: Currently the backup system has not been “battle
tested”. It is suggested that automated backups are introduced when
there are supervision implemented, i.e. Nagios, that monitors success.
Also it is suggested that manual backups are performed for a suitable
time in order to ensure that it works without “hiccups”.

[]{#anchor-37}Way forward – remaining issues
============================================

The SBDI deployment platform is currently not fully tested and
operational. Some features of the backup systems are (because of lack of
time) not yet in place.

In the above sections many remaining issues, possible problems and some
hints on how to solve them have been included. In this section we will
shortly address off site backup replication and performance.

[]{#anchor-38}Off site backup replication
-----------------------------------------

ZFS has built in functionality for off site replication. With ZFS
snapshots (like current) backups may either be sent or pulled from the
Remote Backup Server.

In the SBDI case all that is needed is to make sure the Remote Backup
Server is accessible from the Backup Target Server via ssh. This can be
done in many ways. One way is by making use off the existing IP Sec
server, i.e. connect-1, to setup a tunnel (initiated by the Remote
Backup Server).

Then after a backup has been saved on the Backup Target all that needs
doing is spawning a job that does the equivalent of:

\# zfs send <backup/current@snap_20220906_082043> | ssh
&lt;remote\_backup\_server&gt; zfs recv backup/current\

The following article elaborates this better:
<https://www.howtoforge.com/tutorial/how-to-use-snapshots-clones-and-replication-in-zfs-on-linux>.

Things to consider here is root access. It is suggested that the
unprivileged bakupoperator user is given sudo rights (by means of
*/etc/sudoers*) in order to run the ZFS commands send and receive as
needed.\

Since fully implementing off site backup replication includes a lot of
implementation work like Anisble scripts, setting up users, ssh access,
handling errors, spawning jobs, logging etc it is suggested that making
use of an existing application like TrueNAS (<https://www.truenas.com/>)
is considered. TrueNAS has easy to access graphical configuration
capabilities built in to setup ZFS replication. In this case if the
Remote Backup Server was a TrueNAS installation it would be easier to
simply grant TrueNAS ssh access to the Backup Target Server and
configure a “pull” synchronization.

[]{#anchor-39}Performance
-------------------------

Transferring 5TB (like a full backup) on a 5Gbit network will not take
less than 1000 \* 8 seconds \~ 2 hours and 15 minutes.

Writing or reading 5TB of data to fast industry standard SSD disks with
500MB/s bandwidth takes no less than 10 \* 1000 seconds \~ 2 hours and
46 minutes.\
\
No matter how optimized the Backup and Restore system is we will have to
expect not to be able to perform a full backup in shorter times than
that.\
\
In the last tests performed we measure times close to 25 hours for
backing up 0.5 TB. Incremental backups are significantly faster but we
have not been able to test how fast in practice. Thus we have an
indication of performance 100+ times slower than best possible.

Is this cause for worry?

Unfortunately that is not possible to say. Early indications however are
that using network provided disk as in our case might make the backup
system very slow and possibly even too slow.

What to do?

1.  Increase CPU and RAM
2.  Use faster MTU 9000 networking
3.  Try performance optimizations as suggested above, noatime, faster or
    no encryption, etc
4.  Use ephemeral disk, i.e. local disk
5.  Do not backup Cassandra and Solar data
6.  Use another backup strategy/system

Experiences this far suggests that OpenStack *network provided* volumes
might not make SBDI perform fast enough even with all possible tweaks.
Even though this remains to be tested with lots of data during imports
and indexing we have strong indications that Ephemeral disk is a better
option[^6].

The strategy not to backup Cassandra and Solr may actually be the most
obvious way to go. Cassandra has in itself support for replication and
all data in Solr may be recreated by SBDI itself. In additon to this
when pipelines are introduced in SBDI Cassandra will no longer be used
for records storage.

The option to use another backup strategy or system altogether should be
give careful consideration. In general terms the Backup and Restore
system described in this document provides a solution that makes
integrated use of probably the fastest and most proven open source
technologies available, i.e. LVM snapshots, Rsync, SSH and ZFS.
Designing a faster solution with a similar or comparable mode of
operation but maybe with other components will be difficult. What may
make the current solution impractical or not usable most likely relates
to the fact that it is run within a highly complex complex, i.e. Open
Stack, where issues with virtual network provided storage, virtual
networking etc might interfere destructively with its intended
operation.

What might be worth considering if OpenStack with virtual network
provided storage is unavoidable and no performance tweaks as suggested
does suffice is to *use disruptive technology altogether*. Such
disruptive technology in this case would indicate that the backup
solution should be an integral part of Open Stack. And there are
solutions in OpenStack that may be used. In Open Stack it is possible to
take snapshots of Virtual Machines as well as data volumes. This will be
magnitudes faster but how are these functions to be orchestrated and
provide a similar operation as this Backup and Restore system? How do we
use these functions to take a backup of data and load it into a staging
environment? How do we ensure that all the virtual machines and data on
the data volumes are backed up at the same instance? The very idea with
Using Open Stack for instance is not to have to worry about the
internals of Open Stack.

In order to develop an alternative solution, with better performance,
lateral thinking in combination with another innovative approach
altogether is probably needed.

[]{#anchor-40}Overview reference
================================

Following is an overview diagram of the Backup and Restore system:

[]{#anchor-41}Acknowledgment
============================

The Backup and Restore system described in this document was originally
developed by Hans Höök at Altrusoft AB as part of the open source
AltruSOMO project. It has been tested and used in production for over 10
years. Since the AltruSOMO code was taken off line, when Altrusoft ended
operations, the code developed for SBDI have been retrieved from private
copies and revised and refactored to fit SBDI. The biggest improvements
from the original code is the integration with Ansible and Docker Swarm.

The parts used from the AltruSOMO project is made available as Open
Source Software published under the GNU Lesser General Public License
version 2. Copyright (c) 2009, Altrusoft AB.

[^1]:  The concept of a snapshots in ZFS and LVM differ slightly. In LVM
    a snapshot is something that can be accessed and mounted. In ZFS a
    snapshot may not be accessed. To access it a *Clone* has to be
    created from the snapshot. Clones may then be mounted.

[^2]: https://www.howtogeek.com/517098/linux-file-timestamps-explained-atime-mtime-and-ctime/

[^3]: https://en.wikipedia.org/wiki/Jumbo\_frame

[^4]: Unfortunately we have a shortage of disk space on the current uat
    installation and only 1.5 TB have been allocated.

[^5]: In case the Backup Director is merged with a Backup Source node
    this will become a problem that has to be solved.

[^6]: During development of the first SBDI installation ephemeral disk
    had to be used in order to make some functions like Cassandra
    usable.
