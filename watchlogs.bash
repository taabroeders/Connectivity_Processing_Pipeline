#!/bin/bash

logs_folder=$(realpath $1/logs)
SUBID=${2##sub-}
SESID=${3##ses-}
prev_log='0'
latest_log='1'
wait=0

if [ ! -d $logs_folder ]; then
echo ERROR: incorrect output folder
exit
fi

#check if specific subject+session was selected
while [ $(ls -1 ${logs_folder}/*.out 2>/dev/null | wc -l) -gt 0 ];do
    if [ -z $SESID ] && [ ! -z $SUBID ];then
        FULLID=sub-${SUBID}
        latest_log=$(ls $(grep -l -m 1 "####${FULLID}####" ${logs_folder}/*.out) -t1 | head -n 1)
    elif [ ! -z $SESID ] && [ ! -z $SUBID ];then
        FULLID="sub-${SUBID}: ses-${SESID}"
        latest_log=$(ls $(grep -l -m 1 "####${FULLID}####" ${logs_folder}/*.out) -t1 | head -n 1)
    else
        latest_log=${logs_folder}/$(ls ${logs_folder} -t1 | head -n 1)
    fi

    #prevent infinite while loop but give time write new file (max 1 minute)
    if [ ${prev_log} == ${latest_log} ];then
        wait=$(echo ${wait}+1 | bc);sleep 2;continue
        if [ ${wait} -gt 30 ];then exit;fi
    else
        wait=0
    fi

    #if log is still empty, wait for the first steps to be completed (max 1 minute)
    for ii in {1..29};do if [ ! -s ${latest_log} ]; then sleep 2;else break;fi;done

    prev_log=${latest_log}
    watch -e "
    [ -f ${latest_log} ] || exit 1;
    if [ $(cat ${latest_log} | tail -n1 | grep -q '#### Done! ####') ]; then
    echo 'Note: this script completed. Press any key to continue. It may take a few seconds before the next log file has loaded.'; exit 1;
    fi;
    printf 'Current log: $(realpath ${latest_log})\t(2× ctrl+c to exit)\n\n'; cat ${latest_log} | tail -n $(($(tput lines) - 4))"
done