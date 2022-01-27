#! /bin/bash

latest_snapshot=$(zfs list -t snapshot -o name -s creation | tail -1)

zfs clone $latest_snapshot backup/latest
#zfs destroy backup/latest
