#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
set -a # automatically export all variables
source .env
set +a


docker ps --format "{{.Names}}" > svc_list
rm -rf ${SCRIPT_DIR}/tunnels
mkdir ${SCRIPT_DIR}/tunnels

cloudflared tunnel delete -f bbogyo
cloudflared tunnel create bbogyo > ${SCRIPT_DIR}/tunnels/bbogyo
rm -rf  $SCRIPT_DIR/configs
mkdir $SCRIPT_DIR/configs
touch $SCRIPT_DIR/configs/bbogyo.yaml
cat ${SCRIPT_DIR}/tunnels/bbogyo

tunnel_id=$(cat ${SCRIPT_DIR}/tunnels/bbogyo| grep -o -P '(?<=id).*(?=)')
credential_file=$(cat ${SCRIPT_DIR}/tunnels/bbogyo| grep -o -P '(?<=to).*(?=.json)')
echo tunnel:${tunnel_id} >> $SCRIPT_DIR/configs/bbogyo.yaml
echo credentials-file:${credential_file}.json >> $SCRIPT_DIR/configs/bbogyo.yaml
echo ingress: >> $SCRIPT_DIR/configs/bbogyo.yaml

while read file; do
  echo "$file"
  echo "  - hostname: "$file.$CLOUDFLARE_DNS >> $SCRIPT_DIR/configs/bbogyo.yaml
  if [ $file  =  "plex" ];
  then
    port=32400
  else
    port=$(docker ps --format "{{.Names}}: {{.Ports}}" | grep  $file | grep -o -P '(?<=:).*(?=/tcp)' | grep -o -P '(?<=0.0.0.0:).*(?=->)' | cut -c1-4)
  fi
  echo "    service: http://localhost":$port >> $SCRIPT_DIR/configs/bbogyo.yaml
  cloudflared tunnel route dns --overwrite-dns bbogyo $file.$CLOUDFLARE_DNS  > /dev/null 2>&1
  #cloudflared tunnel --config $SCRIPT_DIR/configs/$file.yaml run $file > /dev/null 2>&1
  echo "cloudflare tunnel running: "$file
done <svc_list

echo "  - service: http_status:404" >> $SCRIPT_DIR/configs/bbogyo.yaml

cat $SCRIPT_DIR/configs/bbogyo.yaml

