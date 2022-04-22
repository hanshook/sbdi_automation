#! /bin/bash

cd $(dirname $0)

from_domain="biodiversitydata.se"
to_domain=${1:-"sbdi-uat.se"}

cd etc/html
if [ ! -d "static.${from_domain}" ]
then
    echo "static.${from_domain} does not exist in $(pwd) - nothing to translate from"
    exit 9
fi

if [ -e "static.${to_domain}" ]
then
    echo "Removing old directory static.${to_domain}"
    rm -rf "static.${to_domain}"
fi

echo  "Copying all files in directory static.${from_domain} to static.${to_domain}"
cp -r "./static.${from_domain}"  "./static.${to_domain}"


echo  "Replacing all \"${from_domain}\" with \"${to_domain}\" in all files in static.${to_domain}"

cd "static.${to_domain}"
files_to_translate=$(grep -r -e "${from_domain}" * | cut -d: -f1 | sort -d | uniq | xargs)

for file_to_translate in ${files_to_translate};
do
    echo "sed -i \"s,${from_domain},${to_domain},g\" ${file_to_translate}"
    sed -i "s,${from_domain},${to_domain},g" ${file_to_translate}
done
