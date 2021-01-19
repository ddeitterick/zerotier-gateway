[![Docker Pulls](https://badgen.net/docker/pulls/zyclonite/zerotier)](https://hub.docker.com/r/zyclonite/zerotier)

## zerotier-docker

#### Description

This is a container based on a lightweight Alpine Linux image and a copy of ZeroTier One. It's designed to allow you to run ZeroTier One as a containerised service including the ability to configure it as a (inbound / outbond / bidirectional) gateway between your local network and the ZT network(s).

#### Run

To run this container in the correct way requires some special options to give it special permissions and allow it to persist its files. Here's an example (tested on Ubuntu 20.04 LTS):

    docker run 
      --name zerotier-gw \
      -v /var/lib/zerotier-one:/var/lib/zerotier-one \
      -e NETWORK_IDS=[ZT_NETWORK_ID1;ZT_NETWORK_ID2] \
      -e GATEWAY_MODE=[inbound|outbound|both] \
      --cap-add=NET_ADMIN \
      --net=net_LAN_ETH0 \
      --ip=172.17.50.137 \
      bfg100k/zerotier


This runs bfg100k/zerotier in a container exposed on the physical network via a macvlan interface. For this to work, you will need to create a docker macvlan network using the following syntax:

    docker network create \
      --driver macvlan \
      --gateway 172.17.50.129 \
      --subnet 172.17.50.128/28 \
      --ip-range 172.17.50.128/28 \
      -o parent=eth0 \
      net_LAN_ETH0

It also mounts /var/lib/zerotier-one to /var/lib/zerotier-one inside the container, allowing your service container to persist its state across restarts of the container itself. If you don't do this it'll generate a new identity every time. You can put the actual data somewhere other than /var/lib/zerotier-one if you want.

To join one or more zerotier networks, you can specify the network ids in the environment variable NETWORK_IDS (semi-colon delimited). 

To configure gateway mode, pass in the environment variable GATEWAY_MODE. You can choose between inbound (i.e. ZT -> Local), outbound (i.e. Local -> ZT) or bidirectional (i.e. Local <-> ZT). Note that for this to work, you will need to enable ip forwarding on the docker host first. Note also that for now, gateway mode will only be configured for the first ZT network (if you have multiple ZT networks connected).

#### Source

https://github.com/zyclonite/zerotier-docker
