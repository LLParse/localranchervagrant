#!/bin/bash -x

rancher_server_ip=${1:-172.22.101.100}
orchestrator=${2:-cattle}
cache_ip=172.22.101.100
os=${3:-rancheros}

if [ "$os" == "rancheros" ]; then
  if [ ! "$(ps -ef | grep dockerd | grep -v grep | grep "$cache_ip")" ]; then
    ros config set rancher.docker.registry_mirror "http://$cache_ip:5000"
    ros config set rancher.system_docker.registry_mirror "http://$cache_ip:5000"
    ros config set rancher.docker.host "['unix:///var/run/docker.sock', 'tcp://0.0.0.0:2375']"
    system-docker restart docker
    sleep 5
  fi

  if [ "$orchestrator" == "kubernetes" ] && [ ! "$(ros engine list | grep current | grep docker-1.12.6)" ]; then
    ros engine switch docker-1.12.6
    system-docker restart docker
    sleep 5
  fi
elif [ "$os" == "ubuntu" ]; then
  apt-get install -y jq
  docker rm -f cadvisor || true
  if [ ! "$(grep 'added by vagrant' /etc/default/docker)" ]; then
    echo -e "# added by vagrant\nDOCKER_OPTS=\"\$DOCKER_OPTS --registry-mirror http://$cache_ip:5000\"\n" >> /etc/default/docker
    service docker restart
  fi
fi

while true; do
  ENV_ID=$(docker run \
    -v /tmp:/tmp \
    --rm \
    appropriate/curl \
      -s \
      "http://$rancher_server_ip/v2-beta/project?name=$orchestrator" | jq '.data[0].id' | tr -d '"')

  if [[ "$ENV_ID" == 1a* ]]; then
    break
  else
    sleep 5
  fi
done


echo Adding host to Rancher Server

docker run \
  -v /tmp:/tmp \
  --rm \
  appropriate/curl \
    -s \
    -X POST \
    -H 'Content-Type: application/json' \
    -H 'accept: application/json' \
    -d "{\"type\":\"registrationToken\"}" \
      "http://$rancher_server_ip/v2-beta/projects/$ENV_ID/registrationtoken"

docker run \
  -v /tmp:/tmp \
  --rm \
  appropriate/curl \
    -s \
    "http://$rancher_server_ip/v2-beta/projects/$ENV_ID/registrationtokens/?state=active" |
      grep -Eo '[^,]*' |
      grep -E 'command' |
      awk '{gsub("\"command\":\"", ""); gsub("\"", ""); print}' |
      head -n1 |
      sh
