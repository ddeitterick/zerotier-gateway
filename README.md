[![Docker Pulls](https://flat.badgen.net/docker/pulls/ddeitterick/zerotier-gateway)](https://hub.docker.com/r/ddeitterick/zerotier-gateway)
[![Docker Stars](https://flat.badgen.net/docker/stars/ddeitterick/zerotier-gateway)](https://hub.docker.com/r/ddeitterick/zerotier-gateway)
[![Tags](https://flat.badgen.net/github/tags/ddeitterick/zerotier-gateway)](https://github.com/ddeitterick/zerotier-gateway/tags)
[![Latest Tag](https://flat.badgen.net/github/tag/ddeitterick/zerotier-gateway)](https://github.com/ddeitterick/zerotier-gateway/tags)
[![Last Commit](https://flat.badgen.net/github/last-commit/ddeitterick/zerotier-gateway)](https://github.com/ddeitterick/zerotier-gateway/commits/master)
[![License](https://flat.badgen.net/github/license/ddeitterick/zerotier-gateway)](https://github.com/ddeitterick/zerotier-gateway/blob/master/LICENSE)

## zerotier-gateway

### Description

This container is based on a lightweight Alpine Linux image and a copy of ZeroTier One. It was primarily designed to run on a Synology NAS and function as a gateway between your local network and ZeroTier network(s). It will run on other amd64-based machines.

The container uses a macvlan network. One of the side effects of using macvlan is that the container can’t access the host, and vice versa. Because of this an additional "bridge" network is used so that ZeroTier clients can access the Synology NAS. Make sure that this network is already created in Docker before performing the steps below.

> **_NOTE:_** The bridge network must use 172.16.100.0/30 because currently the static route to reach the host is hardcoded in main.sh.

### Run

To run this container in the correct way requires some special options to give it special permissions and allow it to persist its files. Here's an example:

    docker create 
      --restart always \
      --network macvlan1 \
      --ip=192.168.1.254 \
      -p 9993:9993/udp \
      --name zerotier-gateway \
      --device=/dev/net/tun \
      --cap-add=NET_ADMIN \
      -v /volume1/docker/zerotier-gateway/zerotier-one:/var/lib/zerotier-one \
      -v /volume1/docker/zerotier-gateway/iptables:/etc/iptables \
      -e NETWORK_IDS="[ZT_NETWORK_ID1;ZT_NETWORK_ID2]" \
      -e DOCKER_HOST="[HOST_IP]" \
      -e MULTIPATH="Enabled" \
      ddeitterick/zerotier-gateway

The environment variable `DOCKER_HOST` specifies the IP address of the computer running Docker (Synology NAS in my example). You will then need to connect the "bridge" network (referenced as bridge-zerotier-gateway in the command below) to the Docker container so that ZeroTier clients can access the Synology NAS IP address:

    docker network connect bridge-zerotier-gateway zerotier-gateway

Finally, you can then start the container:

    docker start zerotier-gateway

This runs ddeitterick/zerotier-gateway in a container exposed on the physical network (i.e. it has its own IP on the local network) via a macvlan interface. More details on macvlan networks and Docker can be found in the references section below. An example of how you can create a macvlan network in Docker is shown below:

    docker network create \
      --driver macvlan \
      --gateway 192.168.1.1 \
      --subnet 192.168.1.0/24 \
      -o parent=ovs_bond0 \
      macvlan1

It also mounts `/volume1/docker/zerotier-gateway/zerotier-one` to `/var/lib/zerotier-one` and `/volume1/docker/zerotier-gateway/iptables` to `/etc/iptables` inside the container, allowing your service container to persist its state across restarts of the container itself. If you don't do this it'll generate a new identity every time. You can put the actual data somewhere other than `/volume1/docker/zerotier-gateway` if you want.

To join one or more ZeroTier networks, you can specify the network ids in the environment variable `NETWORK_IDS` (semi-colon delimited).

To configure as a gateway and to provide network address translation (NAT) for ZeroTier clients accessing services behind the gateway on the local network, you may need to complete a couple of additional tasks:

1) Make sure ip forwarding (`net.ipv4.ip_forward=1`) is enabled on the Synology NAS and stored in `/etc/sysctl.conf` (to make it persistent) before starting the container. (The startup script will check for this and terminate the container if ip forwarding is disabled.)
2) Create the necessary static route(s) for either the ZeroTier network and/or the local network. Static route settings for ZeroTier networks are found in the ZeroTier Central website (https://my.zerotier.com) and you can configure static route(s) for your local network in your home router/gateway admin website.
3) Iptables is used to provide NAT for ZeroTier clients accessing services behind the gateway on the local network. You will need to create a `rules.v4` file and place it in `/etc/iptables`. When the container starts, iptables will import whatever rules are contained in this file.

An example rules.v4 file is shown below:

    *nat
    -A PREROUTING -d 10.x.x.x -j DNAT --to-destination 192.x.x.x
    -A PREROUTING -d 10.x.x.y -j DNAT --to-destination 192.x.x.y
    -I POSTROUTING -o ztXXXXXXXX -j MASQUERADE
    -I POSTROUTING -o ztYYYYYYYY -j MASQUERADE
    -I POSTROUTING -o eth1 -j MASQUERADE
    -I POSTROUTING -o eth0 -j MASQUERADE
    COMMIT

### Multipath (Experimental)

Multipath support is available in ZeroTier. Multipath is a type of link aggregation that allows the simultaneous (or conditional) use of multiple physical links to enable increased total throughput, load balancing, redundancy, and fault tolerance. There are a variety of standard policies available that can be used right out of the box with little to no configuration. These policies are directly inspired by the policies offered by the Linux kernel but are now offered in user-space and are available on all platforms that ZeroTier supports. Additional information is available here: https://docs.zerotier.com/zerotier/multipath

To enable multipath in this container, set the `MULTIPATH` environment variable to `Enabled`. There are a couple of additional items necessary in order for multipath to function correctly:

1. Multiple network interfaces
2. Unique routing tables per interface
3. Enable multipath in ZeroTier local.config file

You will need to make sure that you have multiple network interfaces connected to the container. You can use `docker network connect` to connect any number of additional network inferfaces. Each additional network interface will need to be setup with it's own default gateway. In order to accomplish this, additional routing tables will need to be created. The iproute2 package was installed as a part of this container. Additional routing tables are defined in the `rt_tables` file found in `/etc/iproute2`. You will need to map this file into the container using `-v /volume1/docker/zerotier-gateway/iproute2/rt_tables:/etc/iproute2/rt_tables`. You can put the actual data somewhere other than `/volume1/docker/zerotier-gateway` if you want.

An example rt_tables file is shown below:

    #
    # reserved values
    #
    255	local
    254	main
    253	default
    0	unspec
    #
    # local
    #
    #1	inr.ruhep
    101	ISP_1
    102	ISP_2

In the example above, `101 ISP_1` and `102 ISP_2` are the two routing tables added. With the additional routing tables defined, next you will need to create routes in those routing tables. You will need to create a file called `setuproutes.sh` and place it in the root of the zerotier-one directory.

An example setuproutes.sh file is shown below:

    #!/bin/sh
    IF1="eth1"
    IF2="eth2"
    IP1="172.16.x.x"
    IP2="192.168.y.y"
    P1="172.16.x.1"
    P2="192.168.y.1"
    P1_NET="172.16.x.0/24"
    P2_NET="192.168.y.0/24"
    TBL1="ISP_1"
    TBL2="ISP_2"
    ip route add $P1_NET dev $IF1 src $IP1 table $TBL1
    ip route add default via $P1 table $TBL1
    ip route add $P2_NET dev $IF2 src $IP2 table $TBL2
    ip route add default via $P2 table $TBL2
    ip rule add from $P1_NET table $TBL1
    ip rule add from $P2_NET table $TBL2

This script will create all the necessary routes in order for each network interface to route correctly. Lastly, you will need to enable multipath via the ZeroTier local.config file. All of the multipath options and examples are availble here: https://docs.zerotier.com/zerotier/multipath

### Source
https://github.com/ddeitterick/zerotier-gateway

Forked from:
https://github.com/bfg100k/zerotier-gateway

### References
1) Using Docker with macvlan Interfaces: https://blog.scottlowe.org/2016/01/28/docker-macvlan-interfaces/
2) How to Disable/Enable IP forwarding in Linux: https://linuxconfig.org/how-to-turn-on-off-ip-forwarding-in-linux
