#!/bin/sh
set -e

echo "Trying to create database and users"
if [ -n "${MONGO_INITDB_ROOT_USERNAME:-}" ] && [ -n "${MONGO_INITDB_ROOT_PASSWORD:-}" ]; then
mongo -u $MONGO_INITDB_ROOT_USERNAME -p $MONGO_INITDB_ROOT_PASSWORD --authenticationDatabase $MONGO_INITDB_DATABASE<<EOF
db=db.getSiblingDB('$CAS_AUDIT_DB');
use $CAS_AUDIT_DB;
db.createUser({
  user:  '$CAS_AUDIT_USERNAME',
  pwd: '$CAS_AUDIT_PASSWORD',
  roles: [{
    role: 'readWrite',
    db: '$CAS_AUDIT_DB'
  }]
});
db=db.getSiblingDB('$CAS_TICKETS_DB');
use $CAS_TICKETS_DB;
db.createUser({
  user:  '$CAS_TICKETS_USERNAME',
  pwd: '$CAS_TICKETS_PASSWORD',
  roles: [{
    role: 'readWrite',
    db: '$CAS_TICKETS_DB'
  }]
});
db=db.getSiblingDB('$CAS_SERVICES_DB');
use $CAS_SERVICES_DB;
db.createUser({
  user:  '$CAS_SERVICES_USERNAME',
  pwd: '$CAS_SERVICES_PASSWORD',
  roles: [{
    role: 'readWrite',
    db: '$CAS_SERVICES_DB'
  }]
});
EOF
else
    echo "Necessary credentials  missing, hence exiting database and user creation!"
    exit 403
fi