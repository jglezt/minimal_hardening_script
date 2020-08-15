#!/bin/bash

#set -x
set -e

# =============================================================================
# Scripts Variables
# =============================================================================
export SSH_PORT="5022"

export PERMANENT_SERVICES="firewalld.service chronyd.service"
export MIN_PACKS="nano net-tools traceroute wget perl gcc make kernel-headers kernel-devel firewalld chrony htop open-vm-tools system-config-keyboard yum-utils audit"
export COMPILERS="/usr/bin/gcc /usr/bin/as"

export HOSTNAME=""
export GATEWAY=""

export MAIN_USERS="jglezt"
export MAIN_GROUP="admin"
export ALLOWED_USERS=""
export MAIN_HOME_DIRECTORIES="/home/"

export TCP_PORTS="5022"
export UDP_PORTS="123"

export LIMIT_COMMANDS_SUDO="Cmnd_Alias LIMIT_COMMANDS = ALL, !/usr/bin/passwd, !/usr/bin/su, !/sbin/visudo, !/bin/nano /etc/sudoers !/usr/bin/vi /etc/sudoers, !/bin/nano sudoers !/usr/bin/vi sudoers"
export UNLIMIT_COMMAND_SUDO="ALL=(ALL)       NOPASSWD: ALL"
export LIMIT_COMMAND_SUDO="ALL=NOPASSWD: LIMIT_COMMANDS"
export SUDOERS_FILE="/etc/sudoers.d/01_first"
# =============================================================================
# Scripts Functions
# =============================================================================
# Status: Ready
add_dns(){
    cp ./configs/resolv.conf /etc/resolv.conf
}
# Status: Ready
initial_setup(){
    yum -y install epel-release && yum -y update
    yum -y install $MIN_PACKS
}
# Status: Ready
enable_selinux(){
    sed -i -e "s/SELINUX=disabled/SELINUX=enforcing/g" /etc/selinux/config
    setenforce 1
}
# Status: Testing
#chrony_configure(){
#    cp ./configs/chrony.conf /etc/chrony.conf
#}
# Status: Ready
net_configuration(){
    systemctl stop NetworkManager
    systemctl disable NetworkManager
    chkconfig --level 235 network on
    service network restart
    tee /etc/sysconfig/network <<EOF
NETWORKING=yes
HOSTNAME=$HOSTNAME
GATEWAY=$GATEWAY
EOF
}
# Status: Ready
configure_hostname(){
    hostnamectl set-hostname $HOSTNAME
    systemctl restart systemd-hostnamed
}
# Status: Ready
conf_sysctl(){
    cp ./configs/sysctl.conf /etc/sysctl.conf
    sysctl -p
}
# Status: Ready
# Arguments: create_users (GROUP_NAME) (USER_LIST) (HOME DIRECTORY)
create_users(){
    groupadd $1
    mkdir -p $3
    for USER in $2; do

        echo "Crear usuario $USER? [y|n]: "
        read ANSWER

        if [ ! $ANSWER == "y"  ] && [ ! $ANSWER == " Y " ]; then
            continue
        fi

        # Add user to permited users.
        ALLOWED_USERS="$USER $ALLOWED_USERS"

        if id -u $USER ; then
            echo "Usuario existe!!!"
            continue;
        else
            echo "Creando usuario!!!"
        fi
        # Create User
        useradd -g $1 -d $3/$USER -m -s /bin/bash $USER
        usermod -p '!!' $USER
        mkdir -p $3/$USER/.ssh
        chown $USER:$1 $3/$USER/.ssh
        chmod 700 $3/$USER/.ssh
        # Add key
        cp ./$1_pub/$USER-$1.pub $3/$USER/.ssh/authorized_keys
        chown $USER:$1 $3/$USER/.ssh/authorized_keys
        chmod 600 $3/$USER/.ssh/authorized_keys
    done
}
# Status: Ready
create_admins(){
    echo "Create main group? [y|n]"
    read ANSWER

    if [ $ANSWER == "y"  ] || [ $ANSWER == " Y " ]; then
        create_users $MAIN_GROUP "$MAIN_USERS" $MAIN_HOME_DIRECTORIES
    fi
}
# Status: Ready
create_another_users(){

    echo "Create another group? [y|n]: "
    read ANSWER

    if [ $ANSWER == "y"  ] || [ $ANSWER == " Y " ]; then
        echo "Name of the group: "
        read ADD_GROUP
        groupadd $ADD_GROUP

        echo "Create users? [y|n]: "
        read ANSWER

        while [ $ANSWER == "y" ] || [ $ANSWER == "Y" ]; do
            echo "Home dir of the group (omit / ): "
            read ADD_HOME

            if [ ! -d $ADD_HOME ]; then
                echo "Creating directories..."
                mkdir -p $ADD_HOME
            fi

            echo "User name: "
            read ADD_USER

            ALLOWED_USERS="$USER $ALLOWED_USERS"

            useradd -g $ADD_GROUP -d $ADD_HOME/$ADD_USER -m -s /bin/bash $ADD_USER
            openssl rand -base64 6 | passwd $ADD_USER --stdin -e
            mkdir -p $ADD_HOME/$ADD_USER/.ssh
            ssh-keygen -b 4096 -f $ADD_HOME/$ADD_USER/.ssh/$ADD_USER-www -t rsa
            echo "Coping $ADD_USER-www.pub to $ADD_HOME/$ADD_USER/.ssh/authorized_keys ..."
            cp $ADD_HOME/$ADD_USER/.ssh/$ADD_USER-www.pub $ADD_HOME/$ADD_USER/.ssh/autorized_keys
            chown $ADD_USER:$1 $ADD_HOME/$ADD_USER/.ssh/autorized_keys
            chmod 600 $ADD_HOME/$ADD_USER/.ssh/autorized_keys

            echo "Crear usuarios? [y|n]: "
            read ANSWER
        done
    fi
}
# Status: Later
add_sudoers(){
    echo "$LIMIT_COMMANDS_SUDO" > $SUDOERS_FILE
    for USER in $ALLOWED_USERS; do
        echo "Allow sudo to $USER? [y|n]: "
        read ANSWER

        if [ $ANSWER == "y"  ] || [ $ANSWER == " Y " ]; then
            echo "$USER $UNLIMIT_COMMAND_SUDO" >> $SUDOERS_FILE
            continue
        fi

        echo "$USER $LIMIT_COMMAND_SUDO" >> $SUDOERS_FILE
    done
    cat $SUDOERS_FILE
    chmod 0440 $SUDOERS_FILE
}
# Status: Ready
ssh_banner(){
    cp ./configs/issue.net /etc/issue.net
}
# Status: Ready
permanent_Services(){
    for SERVICE in $PERMANENT_SERVICES; do
        systemctl enable $SERVICE
        systemctl start  $SERVICE
    done
}
# Status: Ready
firewalld_conf(){
    # TCP pors
    for PORT in $TCP_PORTS; do
        firewall-cmd --permanent --zone=public --add-port=$PORT/tcp
    done

    # UDP Ports
    for PORT in $UDP_PORTS; do
        firewall-cmd --permanent --zone=public --add-port=$PORT/udp
    done
    firewall-cmd --reload
}
# Status: Ready
yum_install_limit(){
    sed -i -e "s/installonly_limit=[0-9]*/installonly_limit=2/g" /etc/yum.conf
}
# Status: Ready
solutionTest_AUTH_9328(){
    sed -i -e "s/umask [0-9][0-9][0-9]/umask 027/g" /etc/profile
    for FILE in /etc/profile.d/*
    do
        sed -i -e "s/umask [0-9][0-9][0-9]/umask 027/g" $FILE
    done
}
# Status: Ready
solutionTest_STRG_1846_1840(){
    tee /etc/modprobe.d/blacklist.conf<<EOF
blacklist usb-storage
blacklist firewire-ohci
blacklist firewire-sbp2
EOF
}
# Status: Ready
solutionTest_SSH_7408(){
    yum -y install policycoreutils-python
    semanage port -a -t ssh_port_t -p tcp $SSH_PORT
    firewall-cmd --permanent --zone=public --add-port=$SSH_PORT/tcp
    firewall-cmd --permanent --zone=public --remove-service=ssh
    firewall-cmd --reload
    sed -i -e "s/#Port [0-9]*/Port $SSH_PORT/g" /etc/ssh/sshd_config
    sed -i -e "s/ssh             [0-9]*/ssh             5022/g" /etc/services
    systemctl restart sshd

}
# Status: Ready
configure_ssh(){
    cp ./configs/sshd_config /etc/ssh/sshd_config
    ALLOW_USERS_COMMAND="AllowUsers"
    for USER in $ALLOWED_USERS; do
        ALLOW_USERS_COMMAND="$ALLOW_USERS_COMMAND $USER"
    done

    sed -i.bak "24i\\
$ALLOW_USERS_COMMAND\\
" /etc/ssh/sshd_config

    sed -i -e "s/ssh             [0-9]*/ssh             5022/g" /etc/services
    systemctl restart sshd
}
# Status: Ready
solutionTest_ACCT_9630(){
    cp ./configs/audit.rules /etc/audit/rules.d/audit.rules
    augenrules
    auditctl -R /etc/audit/rules.d/audit.rules
}
# Status: Ready
clean_old_kernels(){
    rpm -q kernel
    package-cleanup --oldkernels --count=2
}

# Status: Ready
solutionTest_HRDN_7222(){
    for COMP in $COMPILERS; do
        chmod 750 $COMP
    done
}

#=============================================================================
# Script Main
# ============================================================================
if [ ! -d "./configs" ]; then
    echo "Execute the script inside the minimal_hardenining_script directory/!!!"
    exit 2
fi
if [ $UID -ne 0 ]; then
    echo "Execute as root." 2>&1
    exit 1
fi


echo "HostName: "
read HOSTNAME
echo "Gateway: "
read GATEWAY

add_dns

initial_setup

clean_old_kernels

enable_selinux

net_configuration

configure_hostname

conf_sysctl

create_admins

create_another_users

add_sudoers

ssh_banner

permanent_Services

solutionTest_SSH_7408

configure_ssh

firewalld_conf

yum_install_limit

solutionTest_AUTH_9328

solutionTest_STRG_1846_1840

solutionTest_ACCT_9630

solutionTest_HRDN_7222

echo "End"
# End of File
