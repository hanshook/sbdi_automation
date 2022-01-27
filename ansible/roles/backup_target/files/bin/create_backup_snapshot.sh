#! /bin/bash

zfs snapshot backup/current@snap_$(date +%Y%m%d_%H%M%S)
