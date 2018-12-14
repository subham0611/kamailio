Place asterisk.sql file in home directory.
Run kamailioInstallationScript with sudo. 
Script will download kamailio in /usr/local/src/kamailio folder.
Kamailio configuration file will be in /usr/local/etc/kamailio.
Replace kamailio.cfg and tls.config file with the file given in github.
Change kamailio and asterisk ip and port in kamailio.cfg and kamailio ip in tls.config file.
For load balancing list all asterisk's ip and port in dipatcher.list file. 

