# SSL-Certs-Gen
Deploy SSL certificates to hosts in a cluster

These days encryption in transit is a must have requirement for majority of the hadoop setups. 
In order to achieve encryption at rest the first step is to create SSL/TLS certificates for all the servers in a hadoop environment. 

Typically a hadoop environment is made up of a large number of inexpensive community hardware i.e. a large number of servers. 
This poses the issues to create, deploy, maintain and rotate a large number of SSL/TLS certificates for a single environment.
Sure we can manually do all of this work but manual repeated work on a large number of servers is difficult and can introduce human error. 

This repository hosts a automated solution for creating and maintaining a large number of host's SSL/TLS certificates. 


Generally organizations try to stay clear of self signed certificates and instead rely on a certificate signing authority. 
The certificate signing authority will provide TLS/SSL signed certificates for each host in an environment. 
Once the certificate signing authority has signed all the certificates for each host there should be 4 files for each server.
- Certificate file in PEM format for the server.
- Private Key file in PEM format for the server.
- Root CA in PEM format.
- Any intermediate CA in PEM format.
After acquiring all the 4 files for each server we need to create proper folder structure and place these certificate file on each server. 
This can be done manually for a small setup (steps are outlined for the same). 
However for a large environment and for doing this multiple time (Rotating certificates) a automated scripted solution is required (Like one in this repository).

# Manual Deployment Steps
Use following steps to create proper security folder structure on each server in an environment
- Take backup of old security folder if any exists.
- Create new security folder like /etc/security/pki
- Copy 4 certificate files to security folder and rename then with host full name
/etc/security/pki/intca-1.pem
/etc/security/pki/rootca.pem
/etc/security/pki/$(hostname -f).key
/etc/security/pki/$(hostname -f).host.pem
- Append /etc/security/pki/$(hostname -f).host.pem then /etc/security/pki/intca-1.pem and finally /etc/security/pki/rootca.pem to a combined PEM file called /etc/security/pki/$(hostname -f).pem
- Generate a <Keystore password to be used for Private Key file and Java Key Stores
- Import private key and certificate chain into a p12 format
openssl pkcs12 -export -in /etc/security/pki/$(hostname -f).pem -inkey /etc/security/pki/$(hostname -f).key -passin pass:<REDACTED> -passout pass:<REDACTED> -out /etc/security/pki/$(hostname -f).p12 -name $(hostname -f)
- Convert p12 keystore file to jks keystore
keytool -importkeystore -srckeystore /etc/security/pki/$(hostname -f).p12 -srcstorepass <REDACTED> -srcstoretype pkcs12 -srcalias $(hostname -f) \
-destkeystore /etc/security/pki/$(hostname -f).jks -deststorepass <REDACTED> -deststoretype jks -destalias $(hostname -f) 2>/dev/null
- Append /etc/security/pki/rootca.pem then /etc/security/pki/intca-1.pem to /etc/security/pki/truststore.pem creating a truststore in PEM format
- Create a password file under /etc/security/key.pw that contains the private key password
- Create symbolic links for all the certs and files under /etc/security/pki/ folder
ln -s $(hostname -f).key agent.key
ln -s $(hostname -f).pem agent.pem
ln -s $(hostname -f).jks agent.jks
ln -s $(hostname -f).pem server.pem
ln -s $(hostname -f).jks server.jks
- Create a copy of default java truststore
cp $JAVA_HOME/jre/lib/security/cacerts $JAVA_HOME/jre/lib/security/jssecacerts
- Import root certificate in java truststore
keytool -importcert -trustcacerts -keystore $JAVA_HOME/jre/lib/security/jssecacerts -storepass "changeit" -file /etc/security/pki/rootca.pem -noprompt -alias Rootca 2>/dev/null



# Automatic deployment
Use following scripts and place them along with other certificate files in /tmp/certs-orig/ folder on a host with password less sudo access to all other hosts
- Place scripts on Main server
/tmp/certs-orig/MasterDeploymentScript.sh
/tmp/certs-orig/COPY_CERT_AND_SCRIPTS_TO_HOSTS.sh
/tmp/certs-orig/scripts/CHECK_PEM_AND_KEY.sh
/tmp/certs-orig/scripts/CERT_SSL_certificate_Script.sh
- Place all server key file and certificate file in /tmp/certs-orig folder
- Place Root CA and intermediate CA files in PEM format as /tmp/certs-orig/RootCA.pem and /tmp/certs-orig/IntCA.pem
- Finally, on main server run script /tmp/certs-orig/MasterDeploymentScript.sh steps 1, 2, 3, 0
