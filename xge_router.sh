#!/bin/bash

trap __exit EXIT

TMPDIR=/tmp/${0##*/}
mkdir -p $TMPDIR

__exit() {
	local ret=$?
	rm -f $TMPDIR/*.$$
	return $ret
}

# set -eux

burst_in=''
burst_out=''
ceil_in=${ceil_in:-1000}
rate_in=${rate_in:-1000}
ceil_out=${ceil_out:-1000}
rate_out=${rate_out:-1000}


LOG() {
	echo "$(date +"%Y-%m-%d %H:%M:%S") $HOSTNAME ${0##*/}[$$]: $@ $DATA"
}

__xge_send() {
	echo "Filter-Id=\"$@\"" | radclient -x $nas_ip coa $coa_psw &>$TMPDIR/radclient.$$
	ret=$?
	# exit 254 отложить передачу, todo возможно и другие схожие busy context и тд
	grep "no response from server" $TMPDIR/radclient.$$ && exit 254
	cat $TMPDIR/radclient.$$
	return $ret
}

user_add() {
	user_accept
}

user_del() {
	__xge_send session remove $ip
}

user_accept() {
	__xge_send ip forward_allow add $ip
	__xge_send ip snat add $ip $snat_ip
}

user_drop() {
	__xge_send ip forward_allow del $ip
	__xge_send ip snat del $ip
}

user_redirect() {
	__xge_send ip redirect add $ip
}

user_redirect_cancel() {
	__xge_send ip redirect del $ip
}

user_rate_set() {
	__xge_send policy set $ip in $rate_in $ceil_in $burst_in out $rate_out $ceil_out $burst_out
}

user_info() {
	__xge_send session info $ip
}

user_test() {
	__xge_send session test $ip
}


user_event_before() {
	:
}

user_event_after() {
	:
}

user_disconnect() {
	__xge_send session disconnect $ip
}
