#!/bin/bash
cd /docker/etc/biocachebackend

docker run --rm --network=sbdi_frontend \
-v biocachebackend_data_nameindex:/data/lucene/namematching \
-v biocachebackend_data_biocachebackend:/data \
--mount type=bind,source=/docker/etc/biocachebackend/config/blacklistMediaUrls.txt,target=/data/biocache/config/blacklistMediaUrls.txt \
--mount type=bind,source=/docker/etc/biocachebackend/config/biocache-config.properties,target=/data/biocache/config/biocache-config.properties  \
-e BIOCACHE_MEMORY_OPTS="-Xmx16g -Xms1g"  \
-it bioatlas/ala-biocachebackend:v2.6.1 bas
