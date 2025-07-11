#!/bin/sh

## Loop update script

CONFIG=opengn2
APP_PATH=/usr/share/$CONFIG
TMP_PATH=/tmp/etc/$CONFIG
LOCK_FILE=/tmp/lock/${CONFIG}_tasks.lock
CFG_UPDATE_INT=0

config_n_get() {
	local ret=$(uci -q get "${CONFIG}.${1}.${2}" 2>/dev/null)
	echo "${ret:=$3}"
}

config_t_get() {
	local index=${4:-0}
	local ret=$(uci -q get "${CONFIG}.@${1}[${index}].${2}" 2>/dev/null)
	echo "${ret:=${3}}"
}

exec 99>"$LOCK_FILE"
flock -n 99
if [ "$?" != 0 ]; then
	exit 0
fi

while true
do

	if [ "$CFG_UPDATE_INT" -ne 0 ]; then

		stop_week_mode=$(config_t_get global_delay stop_week_mode)
		stop_interval_mode=$(config_t_get global_delay stop_interval_mode)
		stop_interval_mode=$(expr "$stop_interval_mode" \* 60)
		if [ -n "$stop_week_mode" ]; then
			[ "$stop_week_mode" = "8" ] && {
				[ "$(expr "$CFG_UPDATE_INT" % "$stop_interval_mode")" -eq 0 ] && /etc/init.d/$CONFIG stop > /dev/null 2>&1 &
			}
		fi

		start_week_mode=$(config_t_get global_delay start_week_mode)
		start_interval_mode=$(config_t_get global_delay start_interval_mode)
		start_interval_mode=$(expr "$start_interval_mode" \* 60)
		if [ -n "$start_week_mode" ]; then
			[ "$start_week_mode" = "8" ] && {
				[ "$(expr "$CFG_UPDATE_INT" % "$start_interval_mode")" -eq 0 ] && /etc/init.d/$CONFIG start > /dev/null 2>&1 &
			}
		fi

		restart_week_mode=$(config_t_get global_delay restart_week_mode)
		restart_interval_mode=$(config_t_get global_delay restart_interval_mode)
		restart_interval_mode=$(expr "$restart_interval_mode" \* 60)
		if [ -n "$restart_week_mode" ]; then
			[ "$restart_week_mode" = "8" ] && {
				[ "$(expr "$CFG_UPDATE_INT" % "$restart_interval_mode")" -eq 0 ] && /etc/init.d/$CONFIG restart > /dev/null 2>&1 &
			}
		fi

		autoupdate=$(config_t_get global_rules auto_update)
		weekupdate=$(config_t_get global_rules week_update)
		hourupdate=$(config_t_get global_rules interval_update)
		hourupdate=$(expr "$hourupdate" \* 60)
		if [ "$autoupdate" = "1" ]; then
			[ "$weekupdate" = "8" ] && {
				[ "$(expr "$CFG_UPDATE_INT" % "$hourupdate")" -eq 0 ] && lua $APP_PATH/rule_update.lua log all cron > /dev/null 2>&1 &
			}
		fi

		TMP_SUB_PATH=$TMP_PATH/sub_tasks
		mkdir -p $TMP_SUB_PATH
		for item in $(uci show ${CONFIG} | grep "=subscribe_list" | cut -d '.' -sf 2 | cut -d '=' -sf 1); do
			if [ "$(config_n_get $item auto_update 0)" = "1" ]; then
				cfgid=$(uci show ${CONFIG}.$item | head -n 1 | cut -d '.' -sf 2 | cut -d '=' -sf 1)
				remark=$(config_n_get $item remark)
				week_update=$(config_n_get $item week_update)
				hour_update=$(config_n_get $item interval_update)
				echo "$cfgid" >> $TMP_SUB_PATH/${week_update}_${hour_update}
			fi
		done

		[ -d "${TMP_SUB_PATH}" ] && {
			for name in $(ls ${TMP_SUB_PATH}); do
				week_update=$(echo $name | awk -F '_' '{print $1}')
				hour_update=$(echo $name | awk -F '_' '{print $2}')
				hour_update=$(expr "$hour_update" \* 60)
				cfgids=$(echo -n $(cat ${TMP_SUB_PATH}/${name}) | sed 's# #,#g')
				[ "$week_update" = "8" ] && {
					[ "$(expr "$CFG_UPDATE_INT" % "$hour_update")" -eq 0 ] && lua $APP_PATH/subscribe.lua start $cfgids cron > /dev/null 2>&1 &
				}

			done
			rm -rf $TMP_SUB_PATH
		}

	fi

	CFG_UPDATE_INT=$(expr "$CFG_UPDATE_INT" + 10)

	sleep 600

done 2>/dev/null
