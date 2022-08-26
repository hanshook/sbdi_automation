#!/bin/sh
CASSANDRA_NODE_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -qf "name=^cassandra"))
echo $CASSANDRA_NODE_IP
NEWCONFIG="local.node.ip="$CASSANDRA_NODE_IP
echo $NEWCONFIG
sed -i "/local.node.ip/c\\$NEWCONFIG" config/biocache-config.properties

echo "Creating local volume for nameindex using global nameindex data"

docker volume create --driver local \
    --opt type=none \
    --opt device=/docker/var/volumes/nameindex/data_nameindex \
    --opt o=bind local_data_nameindex

echo "Creating local volume for biocachebackend"

docker volume create --driver local \
    --opt type=none \
    --opt device=/docker_local/var/volumes/biocachebackend/data_biocachebackend \
    --opt o=bind local_data_biocachebackend

echo "Starting biocachebackend container"

docker run --rm --network=sbdi_frontend \
-v local_data_nameindex:/data/lucene/namematching \
-v local_data_biocachebackend:/data \
--mount type=bind,source=/docker_local/etc/biocachebackend/config/blacklistMediaUrls.txt,target=/data/biocache/config/blacklistMediaUrls.txt \
--mount type=bind,source=/docker_local/etc/biocachebackend/config/biocache-config.properties,target=/data/biocache/config/biocache-config.properties  \
-e BIOCACHE_MEMORY_OPTS="-Xmx16g -Xms1g"  \
-it bioatlas/ala-biocachebackend:v2.6.1 bash
