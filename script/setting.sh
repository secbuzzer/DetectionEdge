#!/bin/bash

print_log() {
    case "$1" in
        Check)
            echo -e "\033[32m[$1] $2\033[0m"
        ;;
        Fail)
            echo -e "\033[31m[$1] $2\033[0m"
        ;;
        Install)
            echo -e "\033[36m[$1] $2\033[0m"
        ;;
    esac
}

if [ "$EUID" -ne 0 ]; then
    print_log Fail "You have to run this script as a root"
    exit
fi

SUPPORT_DOCKER_COMPOSE_VER=1.29.2

EVN_CONFIG="../SecBuzzerESM.env"
NTP_CONFIG="/etc/ntp.conf"
SYSCTL_CONFIG="/etc/sysctl.conf"
LIMITS_CONFIG="/etc/security/limits.conf"

SUPPORT_OS_VER_ARRAY=(
    "Ubuntu:18.04"
)

NTP_ARRAY=(
    "tock.stdtime.gov.tw"
    "watch.stdtime.gov.tw"
    "time.stdtime.gov.tw"
    "clock.stdtime.gov.tw"
    "tick.stdtime.gov.tw"
)

SYSCTL_ARRAY=(
    "vm.max_map_count:262144"
    "net.core.somaxconn:1024"
    "net.core.netdev_max_backlog:5000"
    "net.core.rmem_max:16777216" 
    "net.core.wmem_max:16777216"
    "net.ipv4.tcp_wmem:4096 12582912 16777216"
    "net.ipv4.tcp_rmem:4096 12582912 16777216"
    "net.ipv4.tcp_max_syn_backlog:8096"
    "net.ipv4.tcp_slow_start_after_idle:0"
    "net.ipv4.tcp_tw_reuse:1"
    "net.ipv4.udp_mem:4096 12582912 16777216"
    "net.ipv4.udp_rmem_min:16384"
    "net.ipv4.udp_wmem_min:16384"
    "net.ipv4.ip_local_port_range:10240 65535"
)

LIMITS_ARRAY=(
    "root soft nofile:655360"
    "root hard nofile:655360"
    "* soft nofile:655360"
    "* hard nofile:655360"
)

check_identity() {
    if [ "$EUID" -ne 0 ]; then
        print_log Fail "You have to run this script as a root"
        exit
    fi
    print_log Check "Identity"
}

check_internet() {
    local MODE=`grep -e "DEV_MODE=" -r $EVN_CONFIG 2>&1 | awk -F '='  '{print $2}' | tr [:upper:] [:lower:]`

    if [ "$MODE" == "" ] || [ "$MODE" != "true" ]; then
        local ESM_URL="api.esm.secbuzzer.co"
    else
        print_log Check "Run Dev Mode."
        local ESM_URL="test.api.esm.secbuzzer.co"
    fi
    if `timeout 3 nc -zv "$ESM_URL" 80 &> /dev/null` || `timeout 3 nc -zv "$ESM_URL" 443 &> /dev/null`; then
        print_log Check "ESM API Server Connection"
    else
        print_log Fail "ESM API Server Fail"
        exit
    fi
}

check_os() {
    # Check OS
    if [ -f /etc/os-release ]; then
        # freedesktop.org and systemd
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
        OS=$(uname -s)
        VER=$(uname -r)
        print_log Fail "This Linux version don't support: $OS:$VER"
        exit 1
    fi

    for data in "${SUPPORT_OS_VER_ARRAY[@]}" ; do
        SUPPORT_OS="${data%%:*}"
        SUPPORT_VER="${data##*:}"

        if [ ${OS} == ${SUPPORT_OS} ] && [ "`echo "${VER} >= ${SUPPORT_VER}" | bc`" -eq 1 ]; then
            print_log Check "Support OS"
            sleep 1
            install_tools ${OS}
            check_timezone_ntp ${OS}
        else
            print_log Fail "This Linux version don't support: $OS:$VER"
            exit 1
        fi
    done
}

install_tools() {
    docker_path=`which docker`
    docker_compose_path=`which docker-compose`
    sp="/-\|"
    local apt_pid="docker.io"
    local curl_pid="docker-compose"

    case "$1" in
        Ubuntu)
            if [ "$docker_path" == "" ] || [ "$docker_compose_path" == "" ]; then
                if [ "$docker_path" == "" ]; then
                    apt-get install docker.io -y >/dev/null 2>&1 &
                    apt_pid=$!
                fi
                if [ "$docker_compose_path" == "" ]; then
                    curl -s -L "https://github.com/docker/compose/releases/download/$SUPPORT_DOCKER_COMPOSE_VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose &
                    curl_pid=$!
                fi

                while true; do
                    sleep 1
                    printf "\b${sp:i++%${#sp}:1}"
                    check_apt_value=$(ps -ax | grep -e "${apt_pid}" | grep -v "grep")
                    check_curl_value=$(ps -ax | grep -e "${curl_pid}" | grep -v "grep")

                    if [ "$check_apt_value" == "" ] && [ "$check_curl_value" == "" ]; then
                        if [ "$docker_compose_path" == "" ]; then
                            chmod +x /usr/local/bin/docker-compose
                            ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
                        fi
                        printf "\b"
                        print_log Install "Install Edge packages"
                        return
                    fi
                done

                return
            fi
            print_log Install "No Install Edge packages"
        ;;
    esac
}

setting_ntp() {
    # Mask Defalut NTP Config
    sed -i '/^pool .*.ubuntu.pool.ntp.org iburst$/ s/^\(.*\)$/#\1/g' "$NTP_CONFIG"
    for data in "${NTP_ARRAY[@]}" ; do
        SETTING_KEY="${data%%:*}"
        if `grep $SETTING_KEY "$NTP_CONFIG" &> /dev/null`; then
            continue
        else
            echo pool $SETTING_KEY iburst >> "$NTP_CONFIG"
        fi
    done
    systemctl restart ntp.service
}

check_timezone_ntp() {
    ntp_path=`which ntpd`
    sp="/-\|"
    local apt_pid="ntpd"
    timedatectl set-timezone "Asia/Taipei"
    case "$1" in
        Ubuntu)
            if [ "$ntp_path" == "" ]; then
                apt-get install ntp -y >/dev/null 2>&1 &
                apt_pid=$!

                while true; do
                    sleep 1
                    printf "\b${sp:i++%${#sp}:1}"
                    check_apt_value=$(ps -ax | grep -e "${apt_pid}" | grep -v "grep")

                    if [ "$check_apt_value" == "" ]; then
                        printf "\b"
                        print_log Install "Install NTP packages"
                        return
                    fi
                done
                setting_ntp
                return
            fi
            setting_ntp
            print_log Install "No Install NTP packages"
        ;;
    esac
}

check_setting_sysctl() {
    local flag=0
    print_log Check "Sysctl config"
    # Backup
    cp -n "$SYSCTL_CONFIG"{,.bak}
    for data in "${SYSCTL_ARRAY[@]}" ; do
        SETTING_KEY="${data%%:*}"
        SETTING_VALUE="${data##*:}"
        CONFIG_VALUE=$(cat "$SYSCTL_CONFIG" | grep "$SETTING_KEY" | awk -F '( |)=( |)' '{print $2}')

        if [ "$CONFIG_VALUE" == "$SETTING_VALUE" ]; then
            continue
        fi

        if [ "$CONFIG_VALUE" == "" ]; then
            # Insert
            echo "${SETTING_KEY} = ${SETTING_VALUE}" >> "$SYSCTL_CONFIG"
            flag=1
        else
            # Replace
            sed -i -r "s/^${SETTING_KEY} ?= ?(.*)/${SETTING_KEY} = ${SETTING_VALUE}/g" "$SYSCTL_CONFIG"
            flag=1
        fi
    done

    if [ "$flag" == 1 ]
    then
        sysctl -p > /dev/null 2>&1
    fi
}

check_setting_limits() {
    print_log Check "Limits config"
    # Backup
    cp -n "$LIMITS_CONFIG"{,.bak}

    for data in "${LIMITS_ARRAY[@]}" ; do
        SETTING_KEY="${data%%:*}"
        SETTING_VALUE="${data##*:}"
        CONFIG_VALUE=$(cat "$LIMITS_CONFIG" | grep -e "^${SETTING_KEY}" | awk -F ' ' '{print $4}')

        if [ "$CONFIG_VALUE" == "$SETTING_VALUE" ]; then
            continue
        fi

        if [ "$CONFIG_VALUE" == "" ]; then
            # Insert
            echo "${SETTING_KEY} ${SETTING_VALUE}" >> "$LIMITS_CONFIG"
        else
            # Replace
            sed -i -r "s/^${SETTING_KEY} (.*)/${SETTING_KEY} ${SETTING_VALUE}/g" "$LIMITS_CONFIG"
        fi
    done

}

check_swap_disable() {
    print_log Check "Swap config"
    swapoff -a
    rm -rf /swap.img
    sed -i 's/^\/swap.*/#&/' /etc/fstab

}

check_identity
sleep 1
check_internet
sleep 1
check_os
sleep 1
check_setting_sysctl
sleep 1
check_setting_limits
sleep 1
check_swap_disable
sleep 1
