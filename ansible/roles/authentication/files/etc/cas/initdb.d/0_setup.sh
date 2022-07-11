#!/bin/sh

echo "CREATE DATABASE IF NOT EXISTS \`$USER_STORE_DB\` ;" | "${mysql[@]}"

echo "CREATE USER IF NOT EXISTS '$CAS_FLYWAY_USERNAME'@'%' IDENTIFIED BY '$CAS_FLYWAY_PASSWORD';" | "${mysql[@]}"
echo "GRANT ALL ON \`$USER_STORE_DB\`.* TO \`$CAS_FLYWAY_USERNAME\`@'%';" | "${mysql[@]}"

echo "CREATE USER IF NOT EXISTS '$CAS_DB_USERNAME'@'%' IDENTIFIED BY '$CAS_DB_PASSWORD';" | "${mysql[@]}"
echo "GRANT ALL ON \`$USER_STORE_DB\`.* TO \`$CAS_DB_USERNAME\`@'%';" | "${mysql[@]}"

echo "CREATE USER IF NOT EXISTS '$USER_STORE_DB_USERNAME'@'%' IDENTIFIED BY '$USER_STORE_DB_PASSWORD';" | "${mysql[@]}"
echo "GRANT ALL ON \`$USER_STORE_DB\`.* TO \`$USER_STORE_DB_USERNAME\`@'%';" | "${mysql[@]}"

echo "FLUSH PRIVILEGES;" | "${mysql[@]}"