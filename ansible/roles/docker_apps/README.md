# Docker aplications in SBDI

In the docker_aps folder install scrips for the majority of dockerized aplictions of SBDI are collected.
One role normaly correspomds to a docker swarm stack.

Note! Exactly what dockerized aplictions that are deployed in SBDI is defined in the file:

```
ansible/group_vars/all/docker_apps.yml
```

All docker apps (i.e. stacks) of that file that is found in this directory must include the path:

```
roles/docker_apps/<name_of_docker_app_instal_role>
```

# Staring a docker app



First (only one time) on a manager nopde - setup docker node lables:
```
/opt/sbdi/bin/ensure_docker_host_labels
```
TODO: This currently done all the time by start_docker_app script - change that

Second (only one time) on a manager nopde - setup sbdi_frontent network node:
```
docker network create -d overlay --opt com.docker.network.driver.mtu=1450 --attachable sbdi_frontend
```

Finally on a manager node:
```
/opt/sbdi/bin/start_docker_app
```




#TODO:

All the tasks file are very similar (with intention since the installation structure is suposed to be the same) - it would be greate to break these out into a common ansible role.

Many of the roles here contains the file wait_for_it.sh - install it only once.
