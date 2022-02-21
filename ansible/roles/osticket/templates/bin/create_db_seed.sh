#! /bin/bash
cd $(dirname $0)
{% if deployment_prefix is defined  %}
. /opt/sbdi/lib/log_utils
{% else %}
. log_utils
{% endif %}

cd ..
application_name=${PWD##*/}
log_logging_application="MGM/${application_name}"

cd ${DOCKER_CTX}/etc/${application_name}

export $(grep -v '^#' env/.envosticket | xargs)

[ -z "$MYSQL_HOST" ] &&  log_fatal 91 "MYSQL_HOST not in ./env file" 
[ -z "$MYSQL_DATABASE" ] &&  log_fatal 92 "MYSQL_DATABASE not in ./env file" 
[ -z "$MYSQL_ROOT_PASSWORD" ] &&  log_fatal 93 "MYSQL_ROOT_PASSWORD not in ./env file" 

init_sql_file=${DOCKER_CTX}/etc/${application_name}/db/initdb.d/init.sql

if touch ${init_sql_file}
then
    log_info "Creating database seed: ${init_sql_file}"
else
    log_fatal 2 "Not allowed to create database seed: ${init_sql_file}"
fi

echo "CREATE DATABASE  IF NOT EXISTS \`osticket\` /*!40100 DEFAULT CHARACTER SET utf8 */;" > ${init_sql_file}
echo "USE \`osticket\`;" >>  ${init_sql_file}

if docker exec "${MYSQL_HOST}" /usr/bin/mysqldump -u root --password="${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" >> "${init_sql_file}"
then
    log_info "Created database seed: ${init_sql_file}"
else
    log_fatal 1 "Failed to created database seed: ${init_sql_file}"
fi


