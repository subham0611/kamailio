#!/bin/bash

echo "#Updating repositories"
yum update && yum install -y wget

sudo wget https://dev.mysql.com/get/mysql57-community-release-el7-9.noarch.rpm
sudo rpm -ivh mysql57-community-release-el7-9.noarch.rpm

echo "Installing gcc git-core mysql-server unixODBC-devel flex bison make libssl-dev libcurl4-openssl-dev libxml2-dev libpcre3-dev openssl libunistring-devel"
yum install -y gcc gcc-c++ git-core mysql-server unixODBC-devel flex bison make openssl-devel libxml2-devel openssl libunistring-devel

passwd=`grep 'temporary password' /var/log/mysqld.log`
echo "Your temporary root password $passwd"
mysql_secure_installation

echo "mysql odbc  driver"
# wget https://dev.mysql.com/get/Downloads/Connector-ODBC/5.3/mysql-connector-odbc-5.3.10-linux-ubuntu16.04-x86-64bit.tar.gz --no-check-certificate
#tar -xvf mysql-connector-odbc-8.0.13-linux-glibc2.12-x86-64bit.tar.gz

echo "Switching to /usr/local/src"
cd /usr/local/src/

echo "Downloading kamailio from git"
git clone https://github.com/kamailio/kamailio kamailio
cd kamailio
make include_modules="db_mysql" cfg
make all
make install

mkdir -p /var/run/kamailio

echo "Creating user kamailio"
user=`cut -d: -f1 /etc/passwd | grep kamailio`
if [ -z "$user" ]
then
	sudo useradd --system --shell /bin/false --home /var/run/kamailio kamailio
	chown kamailio:kamailio /var/run/kamailio
fi

touch /usr/local/etc/kamailio/dispatcher.list

cd /usr/local/src/kamailio/src/modules/websocket
make
cd /usr/local/src/kamailio/src/modules/tls
make

mkdir ~/binary
cd /usr/local/src/kamailio/src/modules/
find . -name *.so -exec cp {} ~/binary \;
cp ~/binary/* /usr/local/lib64/kamailio/modules
rm -rf ~/binary

cat <<EOF >/usr/local/etc/kamctlrc
# The Kamailio configuration file for the control tools.
#
# Here you can set variables used in the kamctl and kamdbctl setup
# scripts. Per default all variables here are commented out, the control tools
# will use their internal default values.

## your SIP domain
# SIP_DOMAIN=kamailio.org

## chrooted directory
# $CHROOT_DIR="/path/to/chrooted/directory"

## database type: MYSQL, PGSQL, ORACLE, DB_BERKELEY, DBTEXT, or SQLITE
# by default none is loaded
#
# If you want to setup a database with kamdbctl, you must at least specify
# this parameter.
DBENGINE=MYSQL

## database host
# DBHOST=localhost

## database host
# DBPORT=3306

## database name (for ORACLE this is TNS name)
# DBNAME=kamailio

# database path used by dbtext, db_berkeley or sqlite
# DB_PATH="/usr/local/etc/kamailio/dbtext"

## database read/write user
# DBRWUSER="kamailio"

## password for database read/write user
# DBRWPW="kamailiorw"

## database read only user
# DBROUSER="kamailioro"

## password for database read only user
# DBROPW="kamailioro"

## database access host (from where is kamctl used)
# DBACCESSHOST=192.168.0.1

## database super user (for ORACLE this is 'scheme-creator' user)
# DBROOTUSER="root"

## password for database super user
## - important: this is insecure, targeting the use only for automatic testing
## - known to work for: mysql
# DBROOTPW="dbrootpw"

## database character set (used by MySQL when creating database)
#CHARSET="latin1"

## user name column
# USERCOL="username"


# SQL definitions
# If you change this definitions here, then you must change them
# in db/schema/entities.xml too.
# FIXME

# FOREVER="2030-05-28 21:32:15"
# DEFAULT_Q="1.0"


# Program to calculate a message-digest fingerprint
# MD5="md5sum"

# awk tool
# AWK="awk"

# gdb tool
# GDB="gdb"

# If you use a system with a grep and egrep that is not 100% gnu grep compatible,
# e.g. solaris, install the gnu grep (ggrep) and specify this below.
#
# grep tool
# GREP="grep"

# egrep tool
# EGREP="egrep"

# sed tool
# SED="sed"

# tail tool
# LAST_LINE="tail -n 1"

# expr tool
# EXPR="expr"


# Describe what additional tables to install. Valid values for the variables
# below are yes/no/ask. With ask (default) it will interactively ask the user
# for an answer, while yes/no allow for automated, unassisted installs.
#

# If to install tables for the modules in the EXTRA_MODULES variable.
# INSTALL_EXTRA_TABLES=ask

# If to install presence related tables.
# INSTALL_PRESENCE_TABLES=ask

# If to install uid modules related tables.
# INSTALL_DBUID_TABLES=ask

# Define what module tables should be installed.
# If you use the postgres database and want to change the installed tables, then you
# must also adjust the STANDARD_TABLES or EXTRA_TABLES variable accordingly in the
# kamdbctl.base script.

# Kamailio standard modules
# STANDARD_MODULES="standard acc lcr domain group permissions registrar usrloc msilo
#                   alias_db uri_db speeddial avpops auth_db pdt dialog dispatcher
#                   dialplan"

# Kamailio extra modules
# EXTRA_MODULES="imc cpl siptrace domainpolicy carrierroute userblacklist htable purple sca"


## type of aliases used: DB - database aliases; UL - usrloc aliases
## - default: none
# ALIASES_TYPE="DB"

## control engine: RPCFIFO
## - default RPCFIFO
# CTLENGINE="RPCFIFO"

## path to FIFO file for engine RPCFIFO
# RPCFIFOPATH="/var/run/kamailio/kamailio_rpc_fifo"

## check ACL names; default on (1); off (0)
# VERIFY_ACL=1

## ACL names - if VERIFY_ACL is set, only the ACL names from below list
## are accepted
# ACL_GROUPS="local ld int voicemail free-pstn"

## check if user exists (used by some commands such as acl);
## - default on (1); off (0)
# VERIFY_USER=1

## verbose - debug purposes - default '0'
# VERBOSE=1

## do (1) or don't (0) store plaintext passwords
## in the subscriber table - default '1'
# STORE_PLAINTEXT_PW=0

## Kamailio START Options
## PID file path - default is: /var/run/kamailio/kamailio.pid
# PID_FILE=/var/run/kamailio/kamailio.pid

## Extra start options - default is: not set
# example: start Kamailio with 64MB share memory: STARTOPTIONS="-m 64"
# STARTOPTIONS=
EOF

echo "Creating database tables for kamailio"
/usr/local/sbin/kamdbctl create
mysql -u root -p </usr/local/etc/kamailio/asterisk.sql

cat <<EOF >/usr/local/etc/kamailio/tls.cfg
# Example Kamailio TLS Configuration File
#
     
     # This is the default server domain, settings
     # in this domain will be used for all incoming
     # connections that do not match any other server
     # domain in this configuration file.
     #
    # We do not enable anything else than TLSv1
    # over the public internet. Clients do not have
    # to present client certificates by default.
    #
    [server:default]
    method = TLSv1
    verify_certificate = yes
    require_certificate = no
    private_key = /usr/local/etc/kamailio/CERTS/kamailio.key
    certificate = /usr/local/etc/kamailio/CERTS/cert.crt
    #ca_list = /usr/local/etc/kamailio/tls/cacert.pem
    #crl = /usr/local/etc/kamailio/tls/crl.pem
    
    # This is the default client domain, settings
    # in this domain will be used for all outgoing
    # TLS connections that do not match any other
    # client domain in this configuration file.
    # We require that servers present valid certificate.
    #
    [client:default]
    #method = TLSv1
    verify_certificate = no
    require_certificate = no
    
    # This is an example server domain for TLS connections
    # received from the loopback interface. We allow
    # the use of TLSv1 protocols here, we do
    # not require that clients present client certificates
    # but if they present it it must be valid. We also use
    # a special certificate and CA list for loopback
    # interface.
    #
    [server:172.16.16.169:5061]
    # method = SSLv23
    method = TLSv1
    verify_certificate = no
    require_certificate = no
    private_key = /usr/local/etc/kamailio/CERTS/kamailio.key
    certificate = /usr/local/etc/kamailio/CERTS/cert.crt
    #verify_depth = 3
    #ca_list = local_ca.pem
    #crl = local_crl.pem
    #server_name = kamailio.org
    #server_id = kamailio.org
    
    # Special settings for connecting to the example.sip (1.2.3.4)
    # public SIP server. We do not verify the certificate of the
    # server because it can be expired. The server
    # implements authentication using SSL client
    # certificates so configure the client certificate
    # that was given to use by iptel.org staff here.
    #
    #[client:1.2.3.4:5061]
    #verify_certificate = no
    #certificate = /usr/local/etc/kamailio/tls/example_client.pem
    #private_key = /usr/local/etc/kamailio/tls/example_key.pem
    #ca_list = /usr/local/etc/kamailio/tls/example_ca.pem
    #crl = /usr/local/etc/kamailio/tls/example_crl.pem
    #server_name = example.sip
    #server_id = example.sip
EOF







