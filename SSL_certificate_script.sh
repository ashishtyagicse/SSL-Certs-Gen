#!/bin/bash
# Uncomment following line for debigging
# trap "set +x; sleep 2; set -x" DEBUG

# This script will use pem and key files in the script folder and create a security folder
# Script will also edit the config.ini file to use TLS Level 3


SCRIPTS_FOLDER=/tmp/certs
SECURITY_FOLDER=/etc/security/pki
AGENT_KEY_FILE_PATH=/etc/security/
KEY_PASSWORD=xxxxxxxxxxxxx
KEYSTORE_PASSWORD=xxxxxxxxxxxxx
JAVA_HOME=/usr/java/jdk1.8.0_251-amd64
USE_TLS=1
VERIFY_CERT_FILE=$SECURITY_FOLDER/rootca.pem
CLIENT_KEY_FILE=$SECURITY_FOLDER/agent.key
CLIENT_KEYPW_FILE=$AGENT_KEY_FILE_PATH/agentkey.pw
CLIENT_CERT_FILE=$SECURITY_FOLDER/agent.pem

# Cloudera specific settings
# AGENT_CONFIG_FILE=/etc/cloudera-scm-agent/config.ini

# Terminal colors 
RC='\033[0;31m'
GC='\033[0;32m'
YC='\033[1;33m'
NC='\033[0m'


printf "\nStarting certificate deployment script on host ${YC}$(hostname -f)...${NC}\n"

echo "1) Taking backup of old security folder if it exists"
if [[ -d "$SECURITY_FOLDER" ]] ; then
    echo "    Folder $SECURITY_FOLDER already exists taking backup"
        if [[ -d "$SECURITY_FOLDER-backup-`date +%F`" ]] ; then
        echo "   Backup folder $SECURITY_FOLDER-backup-`date +%F` already exists"
        i=1
        while [[ -d "$SECURITY_FOLDER-backup-`date +%F`-$i" ]] ; do
            let i++
        done
        echo "   Taking new backup in folder $SECURITY_FOLDER-backup-`date +%F`-$i"
        mv $SECURITY_FOLDER $SECURITY_FOLDER-backup-`date +%F`-$i
        else
                echo "   Taking backup in folder $SECURITY_FOLDER-backup-`date +%F`"
                mv $SECURITY_FOLDER $SECURITY_FOLDER-backup-`date +%F`
        fi
fi

echo "2) Creating security folder structure"
mkdir -p $SECURITY_FOLDER

echo "3) Copy certificate files from tmp location to security folder with proper name"
cp $SCRIPTS_FOLDER/IntCA.pem $SECURITY_FOLDER/intca-1.pem
cp $SCRIPTS_FOLDER/RootCA.pem $SECURITY_FOLDER/rootca.pem
cp $SCRIPTS_FOLDER/$(hostname -f).key $SECURITY_FOLDER/$(hostname -f).key
cp $SCRIPTS_FOLDER/$(hostname -f).pem $SECURITY_FOLDER/$(hostname -f).host.pem

echo "4) Creating the combined Pem file"
cat \
$SECURITY_FOLDER/$(hostname -f).host.pem \
$SECURITY_FOLDER/intca-1.pem \
$SECURITY_FOLDER/rootca.pem >> \
$SECURITY_FOLDER/$(hostname -f).pem

echo "5) Using strong password $KEYSTORE_PASSWORD for all the commands. Using password $KEY_PASSWORD for key password"

echo "6) Importing private key and certificate chain into a p12 format"
openssl pkcs12 -export \
-in $SECURITY_FOLDER/$(hostname -f).pem \
-inkey $SECURITY_FOLDER/$(hostname -f).key \
-passin pass:$KEY_PASSWORD \
-passout pass:$KEYSTORE_PASSWORD \
-out $SECURITY_FOLDER/$(hostname -f).p12 \
-name $(hostname -f)

echo "7) Converting keystore from p12 file to jks"
keytool -importkeystore \
-srckeystore $SECURITY_FOLDER/$(hostname -f).p12 \
-srcstorepass $KEYSTORE_PASSWORD \
-srcstoretype pkcs12 \
-srcalias $(hostname -f) \
-destkeystore $SECURITY_FOLDER/$(hostname -f).jks \
-deststorepass $KEYSTORE_PASSWORD \
-deststoretype jks \
-destalias $(hostname -f) 2>/dev/null

echo "8) Creating truststore in pem format"
cat \
$SECURITY_FOLDER/rootca.pem \
$SECURITY_FOLDER/intca-1.pem >> \
$SECURITY_FOLDER/truststore.pem

echo "9) Creating key password file"
if [[ -e  "$AGENT_KEY_FILE_PATH/key.pw" ]] ; then
    mv $AGENT_KEY_FILE_PATH/key.pw $AGENT_KEY_FILE_PATH/key-backup-`date +%F`.pw
    echo $KEY_PASSWORD >> $AGENT_KEY_FILE_PATH/key.pw
else
    echo $KEY_PASSWORD >> $AGENT_KEY_FILE_PATH/key.pw
fi
chown root:root $AGENT_KEY_FILE_PATH/key.pw
chmod 777 $AGENT_KEY_FILE_PATH/key.pw

echo "10) Creating symbolic links for all the certs and files"
ln -s $SECURITY_FOLDER/$(hostname -f).key $SECURITY_FOLDER/agent.key
ln -s $SECURITY_FOLDER/$(hostname -f).pem $SECURITY_FOLDER/agent.pem
ln -s $SECURITY_FOLDER/$(hostname -f).jks $SECURITY_FOLDER/agent.jks
ln -s $SECURITY_FOLDER/$(hostname -f).pem $SECURITY_FOLDER/server.pem
ln -s $SECURITY_FOLDER/$(hostname -f).jks $SECURITY_FOLDER/server.jks


echo "11) Creating default java truststore file"
if [[ ! -f $JAVA_HOME/jre/lib/security/jssecacerts ]] ; then
        cp $JAVA_HOME/jre/lib/security/cacerts $JAVA_HOME/jre/lib/security/jssecacerts
fi

echo "12) Import root certificate in java truststore"
keytool -importcert -trustcacerts \
-keystore $JAVA_HOME/jre/lib/security/jssecacerts \
-storepass "changeit" \
-file $SECURITY_FOLDER/rootca.pem \
-noprompt \
-alias MandTRootca 2>/dev/null


echo "13) Creating java truststore file in $SECURITY_FOLDER folder"
cp $JAVA_HOME/jre/lib/security/jssecacerts $SECURITY_FOLDER/jssecacerts
keytool -storepasswd \
-keystore $SECURITY_FOLDER/jssecacerts \
-storepass "changeit" \
-new $KEYSTORE_PASSWORD 2>/dev/null

echo "14) Change permission for security folder"
chmod -R 755 $SECURITY_FOLDER
chmod -R 755 /opt/cloudera/security/

# Cloudera specific congigurations 
#echo "15) Changing agent config.ini file"
#cp $AGENT_CONFIG_FILE $AGENT_CONFIG_FILE-backup-`date +%F`
#sed -i "s@.*use_tls=.*@use_tls=$USE_TLS@" $AGENT_CONFIG_FILE
#sed -i "s@.*verify_cert_file=.*@verify_cert_file=$VERIFY_CERT_FILE@" $AGENT_CONFIG_FILE
#sed -i "s@.*client_key_file=.*@client_key_file=$CLIENT_KEY_FILE@" $AGENT_CONFIG_FILE
#sed -i "s@.*client_keypw_file=.*@client_keypw_file=$CLIENT_KEYPW_FILE@" $AGENT_CONFIG_FILE
#sed -i "s@.*client_cert_file=.*@client_cert_file=$CLIENT_CERT_FILE@" $AGENT_CONFIG_FILE
#sed -i "s@.*verify_cert_dir=.*@# verify_cert_dir=@" $AGENT_CONFIG_FILE
