# Usefull commands

## Dump html files from wordpress

 ```
 wp_container_id=
 site=main|docs|tools
 docker exec -i $wp_container_id tar cz /var/www/html > ${site}-wordpress-files-$(date "+%Y%m%d-%H%M%S").tgz
 ```

## Dump db files from mysql

 ```
 mysql_container_id=
 site=main|docs|tools
 env_file=
 export $(grep -v '^#' ${env_file} | xargs)
 docker exec -i $mysql_container_id mysqldump --user root --password=$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE | gzip > ${site}-wordpress-db-$(date "+%Y%m%d-%H%M%S").sql.gz

 ```

## Transform files and db dump to a backup

```
gunzip *.sql.gz
sudo apt-get install rename
rename 's/(.*)-wordpress-db-(.*).sql/$1-wordpress-db.sql/' *.sql
rename 's/(.*)-wordpress-files-(.*).tgz/$1-wordpress-files.tgz/' *.tgz

```
