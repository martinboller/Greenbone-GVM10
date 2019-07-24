#! /bin/bash

#####################################################################
#                                                                   #
# Author:       Martin Boller                                       #
#                                                                   #
# Email:        martin                                              #
# Last Update:  2019-07-23                                          #
# Version:      1.01                                                #
#                                                                   #
# Changes:      Initial Version (1.00)                              #
#               Changed to v. 10.0.1                                #
#                                                                   #
# Info:         https://sadsloth.net/post/install-gvm10-src/        #
#                                                                   #
#####################################################################


install_prerequisites() {
    export DEBIAN_FRONTEND=noninteractive;
    # Install prerequisites
    apt-get update;
    apt-get -y install software-properties-common cmake pkg-config libglib2.0-dev libgpgme11-dev uuid-dev libssh-gcrypt-dev libhiredis-dev gcc libgnutls28-dev libpcap-dev libgpgme-dev bison libksba-dev libsnmp-dev libgcrypt20-dev redis-server libsqlite3-dev libical-dev gnutls-bin doxygen nmap libmicrohttpd-dev libxml2-dev apt-transport-https curl xmltoman xsltproc gcc-mingw-w64 perl-base heimdal-dev libpopt-dev graphviz nodejs rpm nsis wget sshpass socat snmp gettext python-polib git;
    # Install newer nodejs
    curl -sL https://deb.nodesource.com/setup_8.x | sudo bash -;
    apt-get update;
    apt-get -y install nodejs;
}

prepare_source() {    
    mkdir -p /usr/local/src/gvm10;
    chown $USER:$USER /usr/local/src/gvm10;
    cd /usr/local/src/gvm10;
    #git clone https://github.com/greenbone/gvmd;
    #git clone https://github.com/greenbone/gsa;
    #git clone https://github.com/greenbone/openvas;
    #git clone https://github.com/greenbone/gvm-libs;
    #git clone https://github.com/greenbone/openvas-smb
    # Download source
    wget -O gvm-libs-10.0.1.tar.gz https://github.com/greenbone/gvm-libs/archive/v10.0.1.tar.gz;
    wget -O openvas-scanner-6.0.1.tar.gz https://github.com/greenbone/openvas-scanner/archive/v6.0.1.tar.gz;
    wget -O gvmd-8.0.1.tar.gz https://github.com/greenbone/gvmd/archive/v8.0.1.tar.gz;
    wget -O gsa-8.0.1.tar.gz https://github.com/greenbone/gsa/archive/v8.0.1.tar.gz;
    wget -O openvas-smb-1.0.5.tar.gz https://github.com/greenbone/openvas-smb/archive/v1.0.5.tar.gz;
    wget -O ospd-1.3.2.tar.gz https://github.com/greenbone/ospd/archive/v1.3.2.tar.gz
    find *.gz | xargs -n1 tar zxvfp;
    sync;
    chown -R $USER:$USER /usr/local/src/gvm10;
    # Create folder to use for system information
    mkdir /mnt/backup/$HOSTNAME;
}

install_gvm_libs() {
    cd /usr/local/src/gvm10;
    cd gvm-libs-10.0.1;
    mkdir build;
    cd build;
    cmake ..;
    make;
    make doc-full;
    make install;
    sync;
}

install_openvas_smb() {
    cd /usr/local/src/gvm10
    #config and build openvas-smb
    cd openvas-smb-1.0.5;
    mkdir build;
    cd build/;
    cmake ..;
    make;
    make install;
    sync;
}

install_openvas() {
    cd /usr/local/src/gvm10
    # Configure and build scanner
    cd openvas-6.0.1;
    mkdir build;
    cd build/;
    cmake ..;
    make;
    make doc-full;
    make install;
    # Fix Redis for OpenVas
    
    sudo sh -c 'cat << EOF > /etc/redis/redis.conf
## REDIS Configuration for openvassd
## 2019-06-23 - Martin
################################## NETWORK #####################################
bind 127.0.0.1
# Protected mode is a layer of security protection, in order to avoid that
# Redis instances left open on the internet are accessed and exploited.
protected-mode yes
# If port 0 is specified Redis will not listen on a TCP socket.
port 0
tcp-backlog 511
unixsocket /var/run/redis/redis-server.sock
unixsocketperm 700
timeout 0
tcp-keepalive 300

################################# GENERAL #####################################
daemonize yes
supervised no
pidfile /var/run/redis/redis-server.pid
loglevel notice
logfile /var/log/redis/redis-server.log
syslog-enabled yes
databases 520
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /var/lib/redis
# Replication
slave-serve-stale-data yes
slave-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
repl-disable-tcp-nodelay no
slave-priority 100

################################### LIMITS ####################################
maxclients 10000

############################## APPEND ONLY MODE ###############################
appendonly no
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes

################################ LUA SCRIPTING  ###############################
lua-time-limit 5000

################################## SLOW LOG ###################################
slowlog-log-slower-than 10000
slowlog-max-len 128

################################ LATENCY MONITOR ##############################
latency-monitor-threshold 0

############################# EVENT NOTIFICATION ##############################
notify-keyspace-events ""

############################### ADVANCED CONFIG ###############################
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit slave 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
aof-rewrite-incremental-fsync yes
EOF'
    sysctl -w net.core.somaxconn=1024;
    sysctl vm.overcommit_memory=1;
    echo "net.core.somaxconn=1024"  >> /etc/sysctl.conf;
    echo "vm.overcommit_memory=1" >> /etc/sysctl.conf;
    echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled;
    echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag;
    systemctl restart redis-server;
    sudo sh -c "cat << EOF > /usr/local/etc/openvas/openvassd.conf
db_address = /var/run/redis/redis-server.sock
EOF"
    sync;
    # Update NVTs 
    greenbone-nvt-sync --curl;
    # Reload all modules
    ldconfig;
    # Start Openvassd
    /usr/local/sbin/openvassd -f --only-cache --config-file=/usr/local/etc/openvas/openvassd.conf;
}

install_gvm() {
    cd /usr/local/src/gvm10;
    # Build Manager
    cd gvmd-8.0.1;
    mkdir build;
    cd build/;
    cmake ..;
    make;
    make doc-full;
    make install;
    sync;
}

install_gsa() {
    ## Install GSA
    cd /usr/local/src/gvm10
    # GSA prerequisites
    curl --silent --show-error https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -;
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list;
    sudo apt-get update;
    sudo apt-get -y install yarn;

    # GSA Install
    cd gsa-8.0.1;
    sed -i 's/#ifdef GIT_REV_AVAILABLE/#ifdef GIT_REVISION/g' ./gsad/src/gsad.c;
    sed -i 's/return root.get_result.commands_response.get_results_response.result/return root.get_result.get_results_response.result/g' ./gsa/src/gmp/commands/results.js;
    mkdir build;
    cd build/;
    cmake ..;
    make;
    make doc-full;
    make install;
    sync;
}

install_gvm_tools() {
    # Install gvm-tools
    pip3 install gvm-tools;
}


configure_openvas() {
    # Configure unit file for openvassd
    sudo sh -c "cat << EOF > /lib/systemd/system/openvassd.service
[Unit]
Description=Start Greenbone Vulnerability Manager Daemon
Wants=network-online.target gvmd.service redis-server.service
After=network-online.target gvmd.service redis-server.service

[Service]
Type=forking
PIDFile=/usr/local/var/run/openvassd.pid
ExecStart=/usr/local/sbin/openvassd
ExecReload=/bin/kill -HUP
# Kill the main process with SIGTERM and after TimeoutStopSec (defaults to
# 1m30) kill remaining processes with SIGKILL
KillMode=mixed
# If this service won't start redis-cli -s /var/run/redis/redis-server.sock flushall

[Install]
WantedBy=multi-user.target
Alias=greenbone-openvas-scanner.service
EOF"
    sync;
    systemctl daemon-reload;
    systemctl enable openvassd.service;
}

configure_gvm() {
    # Create Certificates and admin user
    export GVM_CERTIFICATE_LIFETIME=3650;
    /usr/local/bin/gvm-manage-certs -a;
    echo "User admin for GVM $HOSTNAME " >> /mnt/backup/readme-users.txt;
    /usr/local/sbin/gvmd --create-user=admin >> /mnt/backup/readme-users.txt;
    
    # Create unit file for gvmd
    sudo sh -c 'cat << EOF > /lib/systemd/system/gvmd.service
[Unit]
Description=Start Greenbone Vulnerability Manager Daemon

[Service]
Type=forking
PIDFile=/usr/local/var/run/gvmd.pid
ExecStart=-/usr/local/sbin/gvmd --database=/usr/local/var/lib/gvm/gvmd/gvmd.db

ExecReload=/bin/kill -HUP $MAINPID
# Kill the main process with SIGTERM and after TimeoutStopSec (defaults to
# 1m30) kill remaining processes with SIGKILL
KillMode=mixed

[Install]
WantedBy=multi-user.target
Alias=greenbone-vulnerability-manager.service
EOF'
    sync;
    systemctl daemon-reload;
    systemctl enable gvmd.service;
}

configure_gvm_slave() {
    # Create Certificates and admin user
    export GVM_CERTIFICATE_LIFETIME=3650;
    /usr/local/bin/gvm-manage-certs -a;
    echo "User admin for GVM $HOSTNAME " >> /mnt/backup/readme-users.txt;
    /usr/local/sbin/gvmd --create-user=admin >> /mnt/backup/readme-users.txt;
    
    # Create unit file for gvmd on slave
    sudo sh -c 'cat << EOF > /lib/systemd/system/gvmd.service
[Unit]
Description=Start Greenbone Vulnerability Manager Daemon

[Service]
Type=forking
PIDFile=/usr/local/var/run/gvmd.pid
ExecStart=-/usr/local/sbin/gvmd --database=/usr/local/var/lib/gvm/gvmd/gvmd.db --listen=0.0.0.0 --port=9391

ExecReload=/bin/kill -HUP $MAINPID
# Kill the main process with SIGTERM and after TimeoutStopSec (defaults to
# 1m30) kill remaining processes with SIGKILL
KillMode=mixed

[Install]
WantedBy=multi-user.target
Alias=greenbone-vulnerability-manager.service
EOF'    
    sync;
    systemctl daemon-reload;
    systemctl enable gvmd.service;
}


configure_gsa() {
    # Create unit file for gsad
    mkdir -p /usr/local/lib/systemd/system;
    sudo sh -c "cat << EOF > /usr/local/lib/systemd/system/gsad.service
[Unit]
Description=Greenbone Security Assistant
After=network.target

[Service]
Type=forking
EnvironmentFile=-/usr/local/etc/default/gsad
# Choose modern Crypto Algo's, disable http, Strict Transport Security
ExecStart=-/usr/local/sbin/gsad --port=443 --gnutls-priorities=SECURE256:+SECURE128:-VERS-TLS-ALL:+VERS-TLS1.2 --no-redirect --secure-cookie --http-sts
Restart=always
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
Alias=greenbone-security-assistant.service
EOF"
    sync;
    systemctl daemon-reload;
    systemctl enable gsad.service;
}

configure_greenbone_updates() {
    # cron file for daily updates
    sudo sh -c "cat << EOF  > /etc/cron.daily/greenbone-updates
#! /bin/bash
# updates feeds for Greenbone Vulnerability Manager
/usr/local/sbin/greenbone-nvt-sync --curl;
/usr/bin/logger 'NVT Feed Version $(greenbone-nvt-sync --feedversion)' -t 'greenbone';
sleep 600;
/usr/local/sbin/greenbone-certdata-sync --curl;
/usr/bin/logger 'Certdata Feed Version $(greenbone-certdata-sync --feedversion)' -t 'greenbone';
sleep 600;
/usr/local/sbin/greenbone-scapdata-sync --curl;
/usr/bin/logger 'Scapdata Feed Version $(greenbone-scapdata-sync --feedversion)' -t 'greenbone';
exit 0
EOF"
   sync;
   chmod +x /etc/cron.daily/greenbone-updates;
}

start_services() {
    systemctl daemon-reload;
    systemctl restart gvmd.service;
    systemctl restart openvassd.service;
    systemctl restart gsad.service;    
}


configure_report_cleanup() {
# Cron job to cleanup 1 day old csv files pulled from vuln scanner
    sudo sh -c "cat << EOF  > /etc/cron.daily/cleanupvulndata
#! /bin/bash
## Cleanup scan data csv files older than 1 day
find /opt/VulnWhisperer/data/nessus/*/*.csv -mtime +1 -exec rm {} \
EOF"
    sync;
    chmod +x /etc/cron.daily/cleanupvulndata;
}


##################################################################################################################
## Main                                                                                                          #
##################################################################################################################

main() {
        # Shared components
        install_prerequisites;
        prepare_source;
        
        # Server specific elements
    if [ "$HOSTNAME" = "manticore" ]; 
        then
        # Installation of specific components
        # This is the master server so install GSAD
        install_gvm_libs;
        install_openvas_smb;
        install_openvas;
        install_gvm;
        install_gvm_tools;
        install_gsa;        

        # Configuration of installed components
        configure_gvm;
        configure_openvas;
        configure_gsa;
        configure_greenbone_updates;
        configure_report_cleanup;
        echo $HOSTNAME: $(date) | sudo tee -a /mnt/backup/servers;
    fi
    
    if [ "$HOSTNAME" = "aboleth" ]; 
        then
        # Installation of specific components
        install_gvm_libs;
        install_openvas_smb;
        install_openvas;
        install_gvm;
        configure_gvm_slave;
        install_gvm_tools;
        
        # Configuration of installed components
        configure_openvas;
        configure_greenbone_updates;
        cp /usr/local/var/lib/gvm/CA/cacert.pem /mnt/backup/$HOSTNAME;
        echo $HOSTNAME: $(date) | sudo tee -a /mnt/backup/servers;
    fi

    if [ "$HOSTNAME" = "nessie" ]; 
        then
        # Installation of specific components
        dpkg -i /mnt/backup/Nessus-8.5.0-debian6_amd64.deb;
        systemctl restart nessusd.service;
        configure_report_cleanup;
        echo $HOSTNAME: $(date) | sudo tee -a /mnt/backup/servers;
    fi

    start_services;
    apt-get -y install --fix-policy;
}

main;

exit 0;

##########################################################################################
# Post install instructions
# 
# On master: Create GMP scanner and credentials using account on slave
# copy the cacert.pem file from slave(s)
# Get the ID of the newly created scanner (on master), then modify the scanner to accept the cert from the slave
# gvmd --get-scanners
# gvmd --modify-scannner=<scanner UUID> --scanner-ca-pub=cacert.pem
# gvmd --modify-scanner=08b69003-5fc2-4037-a479-93b440211c73 --scanner-ca-pub=cacert.pem
# Verify the scanner
# gvmd --verify-scanner=08b69003-5fc2-4037-a479-93b440211c73
# Now start using that scanner :)
