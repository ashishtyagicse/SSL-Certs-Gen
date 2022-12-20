#!/bin/bash
# Uncomment following line for debigging
# trap "set +x; sleep 1; set -x" DEBUG

# This script will server as master script for running other certificate deployment scripts 

# Text file with all host names 
ALL_HOSTS_LIST=/tmp/cloudera-certs-orig/ALL_HOSTS
SCRIPTS_FOLDER=/tmp/cloudera-certs-orig


ERRORS=0
ERROR_TEXT=""
OPT=4

clear
while [[ $OPT != 0 ]] ; do
        case $OPT in
                0)
                        clear
                        exit
                ;;
                1)
                        clear
                        echo "Starting script $SCRIPTS_SOURCE_FOLDER/scripts/Copy_certs_and_scripts_to_hosts.sh"
                        sh $SCRIPTS_SOURCE_FOLDER/scripts/Copy_certs_and_scripts_to_hosts.sh
                        OPT=4
                ;;
                2)
                        clear
                        echo "Starting script $SCRIPTS_SOURCE_FOLDER/scripts/Check_pem_and_keys.sh on all hosts"
                        for HOST in $(cat $ALL_HOSTS_LIST) ; do
                                ssh -t -q $HOST "
                                sh $SCRIPTS_SOURCE_FOLDER/scripts/Check_pem_and_keys.sh ;
                                exit ;"
								if [[ $(echo $? ) == 11 ]] ; then
									let ERRORS++
									ERROR_TEXT+="Error on host $HOST \n"
								fi 
                        done
						
						printf "\n\n--------------------------Execution complete----------------------------\n"
						if [[ ! $ERRORS == "0" ]] ; then
							printf "Certs check on all cluster hosts completed with status ${RC}[Errors]${NC}\n"
							printf "Error(s) ${RC}$ERRORS${NC}\n"
							echo "Errors list"
							printf "$ERROR_TEXT\n"
						else
							printf "Certs check on all cluster hosts completed with status ${GC}[Success]${NC}\n"
						fi
                        OPT=4
                ;;
                3)
                        clear
                        echo "Starting script $SCRIPTS_SOURCE_FOLDER/scripts/SSL_certificate_script.sh on all hosts"
                        for HOST in $(cat $ALL_HOSTS_LIST) ; do
                                ssh -t -q $HOST "
                                sh $SCRIPTS_SOURCE_FOLDER/scripts/SSL_certificate_script.sh ;
                                exit ;"
                        done
                        OPT=4
                ;;
                4)
                        printf "\n\n\n\n\n"
                        echo "1) Deploy certificate, key and scripts for creating SSL/TLS certificates"
                        echo "2) Check the pem formatted certificate and key files on all hosts"
                        echo "3) Deploy certificates oh hosts in cloudera security folder structure"
                        printf "Make a selection for script execution (4 to repeat and 0 to exit): "
                        read OPT
                ;;
                *)
                        printf "\n\nIncorrect slection please try again\n"
                        sleep 3
                        OPT=4
                ;;
        esac
done
