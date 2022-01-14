# Automation testing with MicroStack

With a running MicroStack it is possible to run ant test Ansible automation scripts on the local machine.

# Development environment setup

Prerequisite: Ubuntu 20.04

The script `bin/install_microstack.sh` will install [MicroStack](https://microstack.run/) on your machine.
The script will also install a Python virtual environment CLI.

Prior to running `bin/install_microstack.sh` do

`cp etc/microstack.cfg.sample etc/microstack.cfg`

and change any default options according to your preferences. 

To access OpenStack commands and enable execution of Ansible scripts execute

`. mscli`

in a terminal.

To access the MicroStack admin WEB GUI point your broswer at [https://10.20.20.1](https://10.20.20.1) 

## Useful commands

To disable MicroStack and free resource:

`sudo snap disable microstack`

To enable: 

`sudo snap enable microstack`

To remove and start afresh:

`sudo snap remove --purge microstack`

 To remotely access the MicroStack web interface from another computer:

`sudo ssh -N -L 8001:10.20.20.1:443 $USER@<machine_running_microstack>`

Then point your browser at https://localhost:8001
