#!/bin/bash

set -u

if [ $1 = "-h" -o $1 = "--help" ] ; then
	echo 
	echo
	echo "Usage: $0 [setup|add|delall] device sport <rate>"
	echo "       # Default rate is ${RATE}"
	echo "       # Example: $0 add ${DEV} 3333 25mbit"
	echo
	exit 0
fi

ACT=${1:?Missing ACT: setup or add or delall}
if [ $ACT = delall ] ; then
	iptables -F -t mangle
	tc qdisc del dev $DEV root &>-
	exit 0
fi

ROOT_CLASS=1234
setup () {
	# Clean everything
	tc qdisc del dev $DEV root  2>/dev/null

	# Create the root qdisc etc.
	tc qdisc add dev ${DEV} root handle ${ROOT_CLASS}: htb default 10
	tc class add dev ${DEV} parent ${ROOT_CLASS}: classid ${ROOT_CLASS}:10 htb rate 8gbit  ceil 10gbit mtu 1500
	tc qdisc add dev ${DEV} parent ${ROOT_CLASS}:10 fq_codel limit 10240 flows 1024 quantum 1514 memory_limit 32Mb ecn
	# tc qdisc add dev ${DEV} parent ${ROOT_CLASS}:10 sfq perturb 10
}

if [ $ACT = setup ] ; then
	setup
	exit 0
fi

DEV=${2:?Missing Device to configure}
SPORT=${3:?Missing sport}
RATE=20mbit
RATE=${4:-${RATE}}
LIMIT=20000
FLOW_LIMIT=${LIMIT}

add() {
	#iptables -t mangle -A FORWARD -o ${DEV} -p udp --sport ${SPORT} -j MARK --set-mark ${SPORT}
	CLASS_ID=${ROOT_CLASS}:${SPORT}
	tc class add dev ${DEV}  parent $ROOT_CLASS: classid ${CLASS_ID}  htb rate ${RATE} mtu 1500
	tc qdisc add dev ${DEV} parent ${CLASS_ID}  fq maxrate ${RATE} limit ${LIMIT} flow_limit ${FLOW_LIMIT} quantum 1514 initial_quantum 1514 pacing
	tc filter add dev ${DEV} parent $parent:  u32 match ip sport ${SPORT} 0xffff classid ${CLASS_ID}
	#tc filter add dev ${DEV} parent $parent:  protocol ip handle ${SPORT} fw flowid ${CLASS_ID}
}


if [ $ACT = setup ] ; then
	setup
	exit 0
fi
if [ $ACT = add ] ; then
	add
	exit 0
fi
if [ $ACT = delall ] ; then
	delall
	exit 0
fi

echo "Dont know what to do with: $@"
