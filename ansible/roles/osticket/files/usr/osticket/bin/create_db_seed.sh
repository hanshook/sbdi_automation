#! /bin/bash
cd $(dirname $0)
. log_utils
cd ..
application_name=${PWD##*/}
cd ../..
export DOCKER_CTX=${PWD}
deployment_config=${DOCKER_CTX}/etc/${application_name}/deploy/deployment.cnf
[ ! -e "${deployment_config}" ] && log_fatal 71 "${deployment_config} not found"

#export $(grep -v '^#' "${deployment_config}" | xargs -d "\n")
. ${deployment_config}
deployment=${DEPLOYMENT:-unknown deployment}
log_logging_application="MGM/${application_name}(${deployment})" 

cd ${DOCKER_CTX}/etc/${application_name}

export $(grep -v '^#' env/.envosticket | xargs)

[ -z "$MYSQL_HOST" ] &&  log_fatal 91 "MYSQL_HOST not in ./env file" 
[ -z "$MYSQL_DATABASE" ] &&  log_fatal 92 "MYSQL_DATABASE not in ./env file" 
[ -z "$MYSQL_ROOT_PASSWORD" ] &&  log_fatal 93 "MYSQL_ROOT_PASSWORD not in ./env file" 


init_sql_file=${DOCKER_CTX}/etc/${application_name}/db/initdb.d/init.sql
log_info "Creating database seed: ${init_sql_file}"

echo "CREATE DATABASE  IF NOT EXISTS \`osticket\` /*!40100 DEFAULT CHARACTER SET utf8 */;" > ${init_sql_file}
echo "USE \`osticket\`;" >>  ${init_sql_file}

docker exec "${MYSQL_HOST}" /usr/bin/mysqldump -u root --password="${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" >> "${init_sql_file}"




