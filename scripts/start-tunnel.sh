#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# script run from host or vm, respectively
if [ -f $DIR/../Vagrantfile ]; then
  export DOCKER_HOST="tcp://172.22.101.100"
  base_dir=$DIR/..
else
  base_dir=/vagrant
fi

host=$(cat $base_dir/tunnel/host)
port=$(cat $base_dir/tunnel/port)

docker rm -f tunnel || true
docker run \
  -d \
  --name=tunnel \
  --net=host \
  --privileged \
  -v /vagrant:/vagrant \
  --entrypoint=/usr/bin/ssh \
    llparse/tunnel:0.1 \
      -i /vagrant/tunnel/key \
      -R $port:localhost:80 \
      -o StrictHostKeyChecking=no \
        $host \
          'sleep 999999999'
