#!/bin/bash

. /usr/local/lib/carbon.shlib

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

__xge_coa_send() {
	echo "Filter-Id=\"$@\"" | radclient -x $nas_ip coa $coa_psw &>$TMPDIR/radclient.$$
	ret=$?
	# exit 254 отложить передачу, todo возможно и другие схожие busy context и тд
	grep "no response from server" $TMPDIR/radclient.$$ && exit 254
	cat $TMPDIR/radclient.$$
	return $ret
}

user_add() {
	[ "$auth_type" = "1" ] && __xge_coa_send session $ip start IPOE
}

user_del() {
	__xge_coa_send session $ip stop "user_del"
	__xge_coa_send session $ip remove
}

user_accept() {
	[ "$auth_type" = "1" ] && __xge_coa_send session $ip start IPOE
	__xge_coa_send session $ip redirect blocked cancel
	__xge_coa_send session $ip nat $snatip
}

user_drop() {
	__xge_coa_send session $ip redirect blocked
}

user_redirect() {
	__xge_coa_send session $ip redirect negbal
}

user_redirect_cancel() {
	__xge_coa_send session $ip redirect negbal cancel
}

user_rate_set() {
	__xge_coa_send session $ip rate set in $rate_in $ceil_in $burst_in out $rate_out $ceil_out $burst_out

}

user_rate_set_cancel() {
	__xge_coa_send session $ip rate remove
}

user_info() {
	__xge_coa_send session $ip info
}

user_test() {
	__xge_coa_send session $ip test
}


user_event_before() {
	:
}

user_event_after() {
	:
}

user_disconnect() {
	__xge_coa_send session $ip disconnect
}
__xge_list_local(){
    ipset -o save -l $4 | grep add | cut -d ' ' -f 3
}
__xge_ssh_send(){
	echo -e "chroot /app/xge $@\nexit\n" | ssh_send --port ${telnet_port:-33} -u ${telnet_login:-root} -p ${telnet_password:-servicemode} ${nas_ip:-127.0.0.1}
}
users_from_nas() {
	# здесь нельзя использовать coa тк буфер маленький у него и не войдет весь вывод
	local SYNCDIR="/var/lib/event/sync/$nas_ip"
	mkdir -p $SYNCDIR
	if [ "$nas_ip" != "169.1.18.12" ]; then
	    __xge_ssh_send xgesh show list xge_blocked_list | grep '^[0-9].*'  > $SYNCDIR/blocked_list.nas
	    __xge_ssh_send xgesh show list xge_negbal_list | grep '^[0-9].*'  > $SYNCDIR/negbal_list.nas
	    __xge_ssh_send xgesh show list xge_auth_list | grep '^[0-9].*'  > $SYNCDIR/auth_list.nas
	fi
	# чтоб на софтроутере пароль не указывать
	if [ "$nas_ip" = "169.1.18.12" ]; then
	    __xge_list_local xgesh show list xge_blocked_list | grep '^[0-9].*'  > $SYNCDIR/blocked_list.nas
	    __xge_list_local xgesh show list xge_negbal_list | grep '^[0-9].*'  > $SYNCDIR/negbal_list.nas
	    __xge_list_local xgesh show list xge_auth_list | grep '^[0-9].*'  > $SYNCDIR/auth_list.nas
	fi
}

user_info(){
        echo '<pre>' > /tmp/${user_id}_user_info.new
        __xge_coa_send session $ip test human | grep "Reply-Message" | sed -e 's/Reply-Message =//g; s/^\s\+//g; s/^"//g; s/"$//g' >> /tmp/${user_id}_user_info.new
        echo '</pre>' >> /tmp/${user_id}_user_info.new

        mv -f /tmp/${user_id}_user_info.new /tmp/${user_id}_user_info
        chown apache:apache /tmp/${user_id}_user_info
}

user_get_mac() {
	local TMPDIR=/tmp/nas_event_daemon/$nas_ip/user_get_mac/
        mkdir -p $TMPDIR/

	__xge_coa_send session $ip get_mac | grep "Reply-Message" | sed -e 's/Reply-Message =//g; s/^\s\+//g; s/^"//g; s/"$//g' >> ${TMPDIR}/${user_id}

	chmod 777 -R /tmp/nas_event_daemon/
}
