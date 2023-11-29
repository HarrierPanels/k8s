#!/bin/bash

if [ $(id -u) -ne 0 ]; then
    echo "Should run under as root"
    exit $?
fi

DOMAIN_NAME=${EXTERNAL_NAME:-$(hostname -f)}
echo "DOMAIN_NAME=${DOMAIN_NAME}"
echo "EXTERNAL_NAME=${EXTERNAL_NAME}"
echo "RESOLVCONFSRV=${RESOLVCONFSRV}"
echo "LOGLEVEL=${LOGLEVEL}"
echo "NAME='${NAME}'"

mkdir -p /opt/playpit/{frontend,manager}
cat << EOF > /opt/playpit/manager/stop.sh
#!/bin/sh

echo > /var/log/trace.log

if docker ps -qa --filter label=lab | wc -l | grep -w 0
then
    [ -z "\${EXTERNAL_NAME}" ] && docker rm -f playpit-manager
else
    echo "Labs Stand Containers:" | log
    docker ps -f label=lab  | log
    echo "Labs Stand Containers: DONE" | log
    echo "" | log

    echo "Cleaning up:" | log
    docker ps -qa --filter label=lab | xargs -r docker rm -f  | log
    docker volume ls --filter label=lab -q | xargs -r docker volume rm -f  | log
    docker volume prune -f | log
    docker network ls --filter label=lab -q | xargs -r docker network rm  | log
    echo "Cleaning up: DONE" | log
    echo "" | log

    echo "Labs Stand Containers:"  | log
    docker ps -f label=lab  | log
fi

./start.sh k8s
EOF

cat << EOF > /opt/playpit/manager/start.sh
#!/bin/sh

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_DEFAULT_PLATFORM=linux/amd64

echo > /var/log/trace.log

STACKFILE=$(mktemp --version 2>/dev/null | grep GNU >/dev/null && mktemp --suffix .playpit-labs.\${1} || mktemp)
wget -q -O \${STACKFILE} https://playpit-labs-assets.s3-eu-west-1.amazonaws.com/docker-compose/sbeliakou-\${1}-epam.yml
log "fetching stack file"

while ! grep 'lab: yes' \${STACKFILE} >/dev/null; do
    wget -q  -O \${STACKFILE} https://playpit-labs-assets.s3-eu-west-1.amazonaws.com/docker-compose/sbeliakou-\${1}-epam.yml
    sleep 1;
done

log "fetching stack file ... DONE"
echo "" | log

echo "Cleaning up:" | log
docker ps -qa --filter label=lab | xargs -r docker rm -f  2>&1 | log
docker volume ls --filter label=lab -q | xargs -r docker volume rm -f 2>&1 | log
docker volume prune -f | log
docker network ls --filter label=lab -q | xargs -r docker network rm 2>&1 | log
echo "Cleaning up: DONE" | log
echo "" | log

echo "Pulling updates:" | log
docker-compose -f \${STACKFILE} pull 2>&1 | log
echo "Pulling updates: DONE" | log
echo "" | log

echo "Starting New Stack:" | log
docker-compose -f \${STACKFILE} up -d --renew-anon-volumes --remove-orphans 2>&1 | log
echo "Starting New Stack: DONE" | log
echo "" | log
# rm -f \${STACKFILE}

echo "Labs Stand Containers:"  | log
docker ps -f label=lab 2>&1 | log
echo "" | log

echo "Waiting for \${1} stack" | log
echo "" | log
sleep 15
EOF

chmod a+x /opt/playpit/manager/*.sh

sudo docker ps | grep playpit-manager &&
docker rm -f playpit-manager

docker run -d \
    --name playpit-manager \
    -p 127.0.0.1:8082:8082 --pull always \
    -e EXTERNAL_NAME="${DOMAIN_NAME}" \
    -e PLAYPIT_NAME="${NAME}" \
    -e PLAYPIT_REBOOT="/restart" \
    -e RESOLVCONFSRV=${RESOLVCONFSRV} \
    -e PLAYPIT_LL="${LOGLEVEL}" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /opt/playpit/manager/start.sh:/start.sh \
    -v /opt/playpit/manager/stop.sh:/stop.sh \
    --label=playpit-manager \
    --restart=unless-stopped \
    sbeliakou/playpit-manager ||
echo

docker exec playpit-manager /start.sh k8s
