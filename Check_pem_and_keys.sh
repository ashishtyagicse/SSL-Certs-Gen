#!/bin/bash
# Uncomment following line for debigging
# trap "set +x; sleep 1; set -x" DEBUG

# This script will check the pem formatted certificate and key files on the host


SCRIPTS_FOLDER=/tmp/certs
KEY_PASSWORD=xxxxxxxxxxxxx


# Terminal size and color settings
TRMCOL=$(tput cols)
STATUSCOL=20
VALCOL=100
RC='\033[0;31m'
GC='\033[0;32m'
YC='\033[1;33m'
NC='\033[0m'
DEBUG=false
ERROR=0
PASS=PASS
FAIL=FAIL

SignatureAlgorithm=sha256WithRSAEncryption
Issuer="test, CN=Test General Purpose Issuing CA"
PublicKeyAlgorithm=rsaEncryption
PublicKeyLength=2048
IMPALA_LB_FQDN="Test.com"
IMPALA_LB="impalalb"
HIVE_LB_FQDN="Test.com"
HIVE_LB="hivelb"


PrintStatus(){

    if [ $1 == $PASS ];  then
        printf "%-$(($TRMCOL - $STATUSCOL - 2))s  ${GC}%-$(echo $STATUSCOL)s${NC}\n" "$2" "[Passed]";
        if $DEBUG; then
            echo "$3" | xargs | cut -c1-$([ $TRMCOL -le $VALCOL ] && echo "$TRMCOL" || echo "$VALCOL");
        fi
    else
        printf "%-$(($TRMCOL - $STATUSCOL -2))s  ${RC}%-$(echo $STATUSCOL)s${NC}\n" "$2" "[Failed]";
                ERROR=11
        if $DEBUG; then
            echo "$3" | xargs | cut -c1-$([ $TRMCOL -le $VALCOL ] && echo "$TRMCOL" || echo "$VALCOL");
        fi
    fi
}

printf "Starting certificate and key file check on host ${YC}$(hostname -f)...${NC}\n"

if [[ -f "$SCRIPTS_FOLDER/$(hostname -f).pem" ]] ; then
    PrintStatus "$PASS" "Checking if certificate file is available" "$SCRIPTS_FOLDER/$(hostname -f).pem"

        # Checking the algorithum used to encrypt the certificate key
        OUTPUT=$(openssl x509 -in $SCRIPTS_FOLDER/$(hostname -f).pem -noout -text -certopt no_sigdump | grep "Signature Algorithm:" | cut -f2- -d:)
        if grep -q "$SignatureAlgorithm" <<< $OUTPUT ; then
                PrintStatus "$PASS" "Checking Signature Algorithm" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking Signature Algorithm" "$OUTPUT"
        fi

        # Checking Issuer
        OUTPUT=$(openssl x509 -in $SCRIPTS_FOLDER/$(hostname -f).pem -noout -text | grep "Issuer:" | cut -f2- -d:)
        if grep -q "$Issuer" <<< $OUTPUT ; then
                PrintStatus "$PASS" "Checking Issuer" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking Issuer" "$OUTPUT"
        fi

        # Checking validity of certificate for next 2 years
        OUTPUT=$(openssl x509 -in $SCRIPTS_FOLDER/$(hostname -f).pem  -checkend 63113904)
        if  [[ $OUTPUT == "Certificate will not expire" ]] ; then
                PrintStatus "$PASS" "Checking validity for next 2 years" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking validity for next 2 years" "$OUTPUT"
        fi

        # Checking Public Key Algorithm
        OUTPUT=$(openssl x509 -in $SCRIPTS_FOLDER/$(hostname -f).pem -noout -text -certopt no_sigdump | grep "Public Key Algorithm: " | cut -f2- -d:)
        if grep -q "$PublicKeyAlgorithm" <<< $OUTPUT ; then
                PrintStatus "$PASS" "Checking Public Key Algorithm" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking Public Key Algorithm" "$OUTPUT"
        fi

        # Checking Key length
        OUTPUT=$(openssl x509 -in $SCRIPTS_FOLDER/$(hostname -f).pem -noout -text -certopt no_sigdump | grep "Public-Key:" | cut -f2- -d:)
        if grep -q "$PublicKeyLength" <<< $OUTPUT ; then
                PrintStatus "$PASS" "Checking Key length" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking Key length" "$OUTPUT"
        fi

        # Checking Key usage
        OUTPUT=$(openssl x509 -in $SCRIPTS_FOLDER/$(hostname -f).pem -noout -text | grep "X509v3 Key Usage: critical" -A1 | tail -n 1)
        if grep -q "Digital Signature" <<< $OUTPUT ; then
                PrintStatus "$PASS" "Checking Key usage for Digital Signature" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking Key usage for Digital Signature" "$OUTPUT"
        fi
        if grep -q "Key Encipherment" <<< $OUTPUT ; then
                PrintStatus "$PASS" "Checking Key usage for Key Encipherment" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking Key usage for Key Encipherment" "$OUTPUT"
        fi
 

        # Checking for Extended Key Usage
        OUTPUT=$(openssl x509 -in $SCRIPTS_FOLDER/$(hostname -f).pem -noout -text | grep "X509v3 Extended Key Usage:" -A1 | tail -n 1)
        if grep -q "TLS Web Client Authentication" <<< $OUTPUT ; then
                PrintStatus "$PASS" "Checking Extended Key Usage for Client Authentication" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking Extended Key Usage for Client Authentication" "$OUTPUT"
        fi
        if grep -q "TLS Web Server Authentication" <<< $OUTPUT ; then
                PrintStatus "$PASS" "Checking Extended Key Usage for Server Authentication" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking Extended Key Usage for Server Authentication" "$OUTPUT"
        fi

        # Checking Subject Alternative Name
        OUTPUT=$(openssl x509 -in $SCRIPTS_FOLDER/$(hostname -f).pem -noout -text | grep "X509v3 Subject Alternative Name:" -A1 | tail -n 1)
        if [ $(grep -o "$(hostname -f)" <<< $OUTPUT | wc -l) == 1 ] ; then
                PrintStatus "$PASS" "Checking SAN for Host name FQDN" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking SAN for Host name FQDN" "$OUTPUT"
        fi
        if [ $(grep -o "$(hostname)" <<< $OUTPUT | wc -l) == 2 ] ; then
                PrintStatus "$PASS" "Checking SAN for Short host name" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking SAN for Short host name" "$OUTPUT"
        fi
        if [ $(grep -o $IMPALA_LB_FQDN <<< $OUTPUT | wc -l) == 1 ] ; then
                PrintStatus "$PASS" "Checking SAN for Impala LB FQDN" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking SAN for Impala LB FQDN " "$OUTPUT"
        fi
        if [ $(grep -o $IMPALA_LB <<< $OUTPUT | wc -l) == 2 ] ; then
                PrintStatus "$PASS" "Checking SAN for Impala LB shortname" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking SAN for Impala LB shortname" "$OUTPUT"
        fi
        if [ $(grep -o $HIVE_LB_FQDN <<< $OUTPUT | wc -l) == 1 ] ; then
                PrintStatus "$PASS" "Checking SAN for Hive LB FQDN" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking SAN for Hive LB FQDN" "$OUTPUT"
        fi
        if [ $(grep -o $HIVE_LB <<< $OUTPUT | wc -l) == 2 ] ; then
                PrintStatus "$PASS" "Checking SAN for Hive LB shortname" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking SAN for Hive LB shortname" "$OUTPUT"
        fi
        if [ $(grep -o "$(hostname -I | xargs)" <<< $OUTPUT | wc -l) == 1 ] ; then
                PrintStatus "$PASS" "Checking SAN for Host IP" "$OUTPUT"
        else
                PrintStatus "$FAIL" "Checking SAN for Host IP" "$OUTPUT"
        fi

        if [[ -f "$SCRIPTS_FOLDER/$(hostname -f).key" ]] ; then
                PrintStatus "$PASS" "Checking if key file is available" "$SCRIPTS_FOLDER/$(hostname -f).key"
                # Checking Key file
                OUTPUT1=$(openssl x509 -noout -modulus -in $SCRIPTS_FOLDER/$(hostname -f).pem | openssl md5 | awk -F " " '{ print $2}')
                OUTPUT2=$(openssl rsa -noout -modulus -in $SCRIPTS_FOLDER/$(hostname -f).key | openssl md5 | awk -F " " '{ print $2}')
                if [[ $OUTPUT1 == $OUTPUT2 ]] ; then
                        PrintStatus "$PASS" "Checking Key file hash" "$OUTPUT"
                else
                        PrintStatus "$FAIL" "Checking Key file hash" "$OUTPUT"
                fi
        else
                PrintStatus "$FAIL" "Checking if key file is available" "$SCRIPTS_FOLDER/$(hostname -f).key"
        fi

        if [[ -f "$SCRIPTS_FOLDER/RootCA.pem" ]] ; then
                PrintStatus "$PASS" "Checking if RootCA is available" "$SCRIPTS_FOLDER/RootCA.pem"
                if [[ -f "$SCRIPTS_FOLDER/IntCA.pem" ]] ; then
                        PrintStatus "$PASS" "Checking if IntermediateCA is available" "$SCRIPTS_FOLDER/IntCA.pem"
                        cat $SCRIPTS_FOLDER/RootCA.pem $SCRIPTS_FOLDER/IntCA.pem >> /tmp/tempcertchain.pem
                        chmod 777 /tmp/tempcertchain.pem
                        OUTPUT=$(openssl verify -CAfile /tmp/tempcertchain.pem $SCRIPTS_FOLDER/$(hostname -f).pem)
                        if grep -q "OK" <<< $( echo $OUTPUT | cut  -f2- -d:); then
                                PrintStatus "$PASS" "Checking Certificate chain" "$OUTPUT"
                        else
                                PrintStatus "$FAIL" "Checking Certificate chain" "$OUTPUT"
                        fi
                        rm -f /tmp/tempcertchain.pem
                else
                        PrintStatus "$FAIL" "Checking if IntermediateCA is available" "$SCRIPTS_FOLDER/IntCA.pem"
                fi
        else
                PrintStatus "$FAIL" "Checking if RootCA is available" "$SCRIPTS_FOLDER/RootCA.pem"
        fi
else
    PrintStatus "$FAIL" "Checking if certificate file is available" "$SCRIPTS_FOLDER/$(hostname -f).pem"
fi

exit $ERROR
