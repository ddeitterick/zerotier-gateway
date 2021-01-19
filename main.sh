#!/bin/bash
#############################################################
# Main startup script to configure and start ZeroTier
#
# Features
# ========
# # Create TUN device if necessary
# # Join ZT network(s) if specified via ENV var NETWORK_IDS
# # Setup necessary iptable rules to enable gateway function
#
# Author: SidneyC <sidneyc_at_outlook_dot_com>
#
#############################################################
export PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin

#Configurable script settings
RETRY_COUNT=3
SLEEP_TIME=5

#setting up TUN device
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    echo "INFO: No TUN device found. Creating one."
    mknod /dev/net/tun c 10 200
fi

if [ ! -c /dev/net/tun ]; then
        echo 'FATAL ERROR: Failed to find/create /dev/net/tun device.'
        exit 1

fi

#start the ZT service
zerotier-one & export APP_PID=$!

TRY_COUNT=0
while [ $TRY_COUNT -lt $RETRY_COUNT ]
do
    sleep $SLEEP_TIME
    CMD_OUT=$( zerotier-cli status )
    if [ ! -z "$( echo "$CMD_OUT" | grep "ONLINE" )" ]; then
        TRY_COUNT=$RETRY_COUNT
        echo "INFO: ZeroTier service is now ONLINE. Your ZT address is $( echo "$CMD_OUT" | cut -f3 -d' ' )."
    else
        TRY_COUNT=`expr $TRY_COUNT + 1`
        if [ $TRY_COUNT -eq $RETRY_COUNT ]; then
            echo "FATAL ERROR: $CMD_OUT"
            exit 1
        fi
    fi
done
#service up and ONLINE!

#join one or more network(s) if specified 
if [ ! -z "$NETWORK_IDS" ]; then
    while IFS= read -d ';' LINE; do
echo "$LINE"
        CMD_OUT=$( zerotier-cli join $LINE )
        if [ -z "$( echo "$CMD_OUT" | grep "200 join OK" )" ]; then
            echo "ERROR: Could not join network ($LINE). MSG is <$CMD_OUT>"
        else
            echo "INFO: Joined network $LINE"
        fi
    done <<< "$NETWORK_IDS"
fi

#log what network is connected
CMD_OUT=$( zerotier-cli listnetworks )
CON_COUNT=$( echo "$CMD_OUT" | grep -v "<nwid>" | wc -l )
if [ $CON_COUNT -lt 1 ]; then
    echo "WARNING: No networks configured!"
else
    echo "INFO: Networks configured - $CON_COUNT."
    echo "INFO: Networks connected - $( echo "$CMD_OUT" | grep "OK" | wc -l )."
fi
while IFS= read -r LINE; do
    if [ ! -z "$( echo "$LINE" | grep "OK" )" ]; then
        FIELDS=($LINE)
        echo "INFO: Connected to ${FIELDS[6]} network with name <${FIELDS[3]}> and id <${FIELDS[2]}> using interface <${FIELDS[7]}> with MAC <${FIELDS[4]}> and IP <${FIELDS[8]}>" 
    fi
done <<< "$CMD_OUT"

#configure iptables if gateway mode is specified
#TODO: add support for multiple ZT gateways using gateway config file
if [ ! -z $GATEWAY_MODE ]; then
    #check if ip forwarding is configured and active
    if [ -z $( sysctl net.ipv4.ip_forward | cut -f3 -d' ' ) ]; then
        echo "FATAL ERROR: ip forwarding not enabled in host, Gateway mode will not work. Please enable ip forwarding in host before starting the container again."
        exit 1
    fi

    #Set local inteface to eth0 if not specified
    [ -z $LO_DEV ] && LO_DEV=eth0

    #Set ZT interface to first connected network in the list if not specified
    [ -z $ZT_DEV ] && ZT_DEV=$( zerotier-cli listnetworks | grep -m 1 "OK" | cut -f8 -d' ' ) 
    case ${GATEWAY_MODE,,} in
        inbound)
            echo "INFO: Configuring iptables for inbound access (ZT<$ZT_DEV> -> local<$LO_DEV>)."
            iptables -t nat -C POSTROUTING -o $LO_DEV -j MASQUERADE 2>/dev/null || {
              iptables -t nat -A POSTROUTING -o $LO_DEV -j MASQUERADE
            }
            iptables -C FORWARD -i $LO_DEV -o $ZT_DEV -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || {
              iptables -A FORWARD -i $LO_DEV -o $ZT_DEV -m state --state RELATED,ESTABLISHED -j ACCEPT
            }
            iptables -C FORWARD -i $ZT_DEV -o $LO_DEV -j ACCEPT 2>/dev/null || {
              iptables -A FORWARD -i $ZT_DEV -o $LO_DEV -j ACCEPT
            }
        ;;

        outbound)
            echo "INFO: Configuring iptables for outbound access (ZT<$ZT_DEV> <- local<$LO_DEV>)."
            iptables -t nat -C POSTROUTING -o $ZT_DEV -j MASQUERADE 2>/dev/null || {
              iptables -t nat -A POSTROUTING -o $ZT_DEV -j MASQUERADE
            }
            iptables -C FORWARD -i $ZT_DEV -o $LO_DEV -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || {
              iptables -A FORWARD -i $ZT_DEV -o $LO_DEV -m state --state RELATED,ESTABLISHED -j ACCEPT
            }
            iptables -C FORWARD -i $LO_DEV -o $ZT_DEV -j ACCEPT 2>/dev/null || {
              iptables -A FORWARD -i $LO_DEV -o $ZT_DEV -j ACCEPT
            }
        ;;

        both)
            echo "INFO: Configuring iptables for bidirectional access (ZT<$ZT_DEV> <> local<$LO_DEV>)."
            iptables -t nat -C POSTROUTING -o $LO_DEV -j MASQUERADE 2>/dev/null || {
              iptables -t nat -A POSTROUTING -o $LO_DEV -j MASQUERADE
            }
            iptables -t nat -C POSTROUTING -o $ZT_DEV -j MASQUERADE 2>/dev/null || {
              iptables -t nat -A POSTROUTING -o $ZT_DEV -j MASQUERADE
            }
            iptables -C FORWARD -i $LO_DEV -o $ZT_DEV -j ACCEPT 2>/dev/null || {
              iptables -A FORWARD -i $LO_DEV -o $ZT_DEV -j ACCEPT
            }
            iptables -C FORWARD -i $ZT_DEV -o $LO_DEV -j ACCEPT 2>/dev/null || {
              iptables -A FORWARD -i $ZT_DEV -o $LO_DEV -j ACCEPT
            }
        ;;
        *)
            echo "ERROR: Unknown Gateway mode ($GATEWAY_MODE)."
        ;;
    esac
fi

wait $APP_PID
exit 0

