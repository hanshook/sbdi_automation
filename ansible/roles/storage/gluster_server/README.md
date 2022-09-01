# Gluster FS

## Overview

TBD


## Notes

Output from health check

```
# gluster volume heal docker info
Brick uat-manager-1:/export/docker/gluster
<gfid:2bbd4b10-faff-4811-a55f-1aa6302ff8a2> 
Status: Connected
Number of entries: 1

Brick uat-manager-2:/export/docker/gluster
<gfid:2bbd4b10-faff-4811-a55f-1aa6302ff8a2> 
Status: Connected
Number of entries: 1

Brick uat-manager-3:/export/docker/gluster
Status: Connected
Number of entries: 0

```

Crude method to resolve this (on manager-1):

```
cd /export/docker/.glusterfs
find . -name 2bbd4b10-faff-4811-a55f-1aa6302ff8a2
./indices/xattrop/2bbd4b10-faff-4811-a55f-1aa6302ff8a2
./2b/bd/2bbd4b10-faff-4811-a55f-1aa6302ff8a2

rm -rf ./2b/bd/2bbd4b10-faff-4811-a55f-1aa6302ff8a2 ./indices/xattrop/2bbd4b10-faff-4811-a55f-1aa6302ff8a2

```

Result:
```
gluster volume heal docker info
Brick uat-manager-1:/export/docker/gluster
Status: Connected
Number of entries: 0

Brick uat-manager-2:/export/docker/gluster
<gfid:2bbd4b10-faff-4811-a55f-1aa6302ff8a2> 
Status: Connected
Number of entries: 1

Brick uat-manager-3:/export/docker/gluster
Status: Connected
Number of entries: 0

```

Repeated same procedure on manager-2 resloved the issue.


