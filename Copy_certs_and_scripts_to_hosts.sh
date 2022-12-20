#!/bin/bash
# Uncomment following line for debigging
# trap "set +x; sleep 1; set -x" DEBUG

# This script will deploy certificate, key and scripts for creating SSL/TLS certificates folder from cloudera manager node to all other nodes in the cluster
# By default folder /tmp/cloudera-certs-orig on Cloudera manager node contains certificates for all the hosts and corresponding scripts


echo "Starting delpoyment of certs and scripts folder to cluster hosts"

SCRIPTS_FOLDER=/tmp/cloudera-certs
SCRIPTS_SOURCE_FOLDER=/tmp/cloudera-certs-orig
ALL_HOSTS_LIST=/tmp/cloudera-certs-orig/ALL_HOSTS

# Terminal size and color settings
TRMCOL=$(tput cols)
STATUSCOL=20
VALCOL=100
ERRORS=0
ERROR_TEXT=""
RC='\033[0;31m'
GC='\033[0;32m'
YC='\033[1;33m'
NC='\033[0m'


for HOST in $(cat $ALL_HOSTS_LIST) ; do
printf "Starting on host ${YC}$HOST...${NC}\n"

ssh -t -q $HOST <<- SSHCOMMAND
        if [[ -d "$SCRIPTS_FOLDER" ]] ; then
                i=1
                while [[ -d "$SCRIPTS_FOLDER-backup-$(date +%F)-\$i" ]] ; do
                        let i++
                done
                printf "%-$(($TRMCOL - $STATUSCOL - 2))s" "Scripts folder already exists taking backup in folder $SCRIPTS_FOLDER-backup-$(date +%F)-\$i        "
                mv $SCRIPTS_FOLDER "$SCRIPTS_FOLDER-backup-$(date +%F)-\$i"
                mkdir $SCRIPTS_FOLDER
                chmod 777 $SCRIPTS_FOLDER
                printf "${GC}%-$(echo $STATUSCOL)s${NC}\n" "[DONE]"
        else
                printf "%-$(($TRMCOL - $STATUSCOL - 2))s" "Creating Scripts folder $SCRIPTS_FOLDER        "
                mkdir $SCRIPTS_FOLDER
                chmod 777 $SCRIPTS_FOLDER
                printf "${GC}%-$(echo $STATUSCOL)s${NC}\n" "[DONE]"
        fi
SSHCOMMAND

        if [[ ! -f "$SCRIPTS_SOURCE_FOLDER/$HOST.pem" ]] ; then
                let ERRORS++
                ERROR_TEXT+="For host $HOST: File not found $SCRIPTS_SOURCE_FOLDER/$HOST.pem \n"
        else
                printf "%-$(($TRMCOL - $STATUSCOL - 2))s" "Copying $HOST.pem file        "
                scp -q "$SCRIPTS_SOURCE_FOLDER/$HOST.pem" "$HOST:/$SCRIPTS_FOLDER/"
                printf "${GC}%-$(echo $STATUSCOL)s${NC}\n" "[DONE]"
        fi
        if [[ ! -f "$SCRIPTS_SOURCE_FOLDER/$HOST.key" ]] ; then
                let ERRORS++
                ERROR_TEXT+="For host $HOST: File not found $SCRIPTS_SOURCE_FOLDER/$HOST.key \n"
        else
                printf "%-$(($TRMCOL - $STATUSCOL - 2))s" "Copying $HOST.key file        "
                scp -q "$SCRIPTS_SOURCE_FOLDER/$HOST.key" "$HOST:/$SCRIPTS_FOLDER/"
                printf "${GC}%-$(echo $STATUSCOL)s${NC}\n" "[DONE]"
        fi
                if [[ ! -f "$SCRIPTS_SOURCE_FOLDER/RootCA.pem" ]] ; then
                let ERRORS++
                ERROR_TEXT+="For host $HOST: File not found $SCRIPTS_SOURCE_FOLDER/RootCA.pem \n"
        else
                printf "%-$(($TRMCOL - $STATUSCOL - 2))s" "Copying RootCA.crt file        "
                scp -q "$SCRIPTS_SOURCE_FOLDER/RootCA.pem" "$HOST:/$SCRIPTS_FOLDER/RootCA.pem"
                printf "${GC}%-$(echo $STATUSCOL)s${NC}\n" "[DONE]"
        fi
                if [[ ! -f "$SCRIPTS_SOURCE_FOLDER/IntCA.pem" ]] ; then
                let ERRORS++
                ERROR_TEXT+="For host $HOST: File not found $SCRIPTS_SOURCE_FOLDER/IntCa.pem \n"
        else
                printf "%-$(($TRMCOL - $STATUSCOL - 2))s" "Copying InterMediateCA file        "
                scp -q "$SCRIPTS_SOURCE_FOLDER/IntCA.pem" "$HOST:/$SCRIPTS_FOLDER/IntCA.pem"
                printf "${GC}%-$(echo $STATUSCOL)s${NC}\n" "[DONE]"
        fi
        if [[ ! -d "$SCRIPTS_SOURCE_FOLDER/scripts" ]] ; then
                let ERRORS++
                ERROR_TEXT+="For host $HOST: Script folder not found $SCRIPTS_SOURCE_FOLDER/scripts  \n"
        else
                printf "%-$(($TRMCOL - $STATUSCOL - 2))s" "Copying Scripts Folder        "
                scp -q -r "$SCRIPTS_SOURCE_FOLDER/scripts" "$HOST:/$SCRIPTS_FOLDER/"
                printf "${GC}%-$(echo $STATUSCOL)s${NC}\n" "[DONE]"
        fi
        printf "%-$(($TRMCOL - $STATUSCOL - 2))s" "Setting permissions for certs and scripts Folder        "
        ssh -t -q $HOST "chmod -R 777 $SCRIPTS_FOLDER/ ; exit ;"
        printf "${GC}%-$(echo $STATUSCOL)s${NC}\n" "[DONE]"
        printf "%-$(($TRMCOL - $STATUSCOL - 2))s" "Removing extra attribtes from certificate pem file      "
        ssh -t -q $HOST "sed -i '/BEGIN/,\$!d' $SCRIPTS_FOLDER/$HOST.pem ; exit ;"
        printf "${GC}%-$(echo $STATUSCOL)s${NC}\n" "[DONE]"
        printf "%-$(($TRMCOL - $STATUSCOL - 2))s" "Removing extra attribtes from private key file      "
        ssh -t -q $HOST "sed -i '/BEGIN/,\$!d' $SCRIPTS_FOLDER/$HOST.key ; exit ;"
        printf "${GC}%-$(echo $STATUSCOL)s${NC}\n" "[DONE]"

done
printf "\n\n--------------------------Execution complete----------------------------\n"
if [[ ! $ERRORS == "0" ]] ; then
        printf "Certs and scripts copy to cluster hosts completed with status ${RC}[Errors]${NC}\n"
        printf "Error(s) ${RC}$ERRORS${NC}\n"
        echo "Errors list"
        printf "$ERROR_TEXT\n"
else
        printf "Certs and scripts copy to cluster hosts completed with status ${GC}[Success]${NC}\n"
fi


