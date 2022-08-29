# SBDI 2.0 Deployment Platform

One might regard SBDI to consist primarily of three tiers:
1. Computation Platform
2. Deployment Platform
3. Applications, i.e. Docker Swarm Services
	
## Computation Platform

The Computation Platform consists of hardware, networking, processors, operating system, hypervisor etc. In our case we have thus far used OpenStack. Doing so is not based on technical requirements but rather by historical reasons. In fact the requirements of the second tier is simple. It is fulfilled by a much simpler setup, like virsh on libvirt, https://en.wikipedia.org/wiki/Libvirt,  on four Ubuntu servers with adequate RAM and disk.

## Deployment Platform
This repository contains mainly the second tier of SBDI 2.0 deployment.
This second tier, the Deployment Platform, is in essence a set of KVM virtual machines and a set of Ansible scripts that together provides the following services:

1. Automated setup of the deployment platform (by the Ansible scripts).  In this way any number of identical deployments, like production, staging, test etc my be setup automatically.
2. Resource configuration. All resources allocated to the deployment platform, like type of machine, disk sizes etc is configured in one file.
3. Automatic deployment of the third tier of Docker Swarm Services (by Ansible scripts).
4. Running a set of Docker Swarm Services. This is the major raison d'être for the second tier.
5. A framework for configuring, naming and grouping the SBDI Docker Swarm Services into convenient packages (referred to ass “docker apps”).
6. Tools for maintenance and supervision of the docker Swarm Services (i.e. starting, stopping, overviewing, monitoring health and resources used etc).
7. Backup and restore of the entire deployment of Docker Swarm Services (data and configuration).
8. Off site backup safekeeping.
9. The possibility to take the backup of one deployment, i.e. Docker Swarm Services including data and configuration, and restoring it on another. This is typically useful when loading a staging environment with production data or moving the SBDI to another location altogether. 
10. Security and isolation, i.e. ensuring that the any external party may not intrude or access any data and services in an undesired way.
11. Redundancy that will ensure that if a virtual machine crashes ore a data volume is corrupted the system will run on with zero downtime. In case the computation platform consists of physical servers any one of those servers should be allowed to fail or be shut down without downtime.
12. Automated software upgrade of the Deployment platform without downtime.
13. Centralized logging for analysis of errors and intrusions.
14. Automated supervision of the platform and the Docker Swarm Services. The supervision system will issue alarms when problems or errors are detected. 


# About this repository

SBDI Deployment Platform automated maintenance and setup

## The ansible subdirectory

In the ansible subdirectory all configuration and scripts for seting up an SBDI 2.0 deployemnt are found.
Currently documention is ongoing.

## The microstack subdirectory

In the microstack directory we find a set of scripts for setting up a development Computaion Platform in microstack.



Note: This git repo contains other SBDI git repos as submodules

To clone; ```git clone --recurse-submodules git@github.com:biodiversitydata-se/automation.git```



