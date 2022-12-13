#!/usr/bin/env bash

ceph_env() {
    CLUSTER=ceph
    # FSID=$(cat /proc/sys/kernel/random/uuid)
    FSID=598dc69c-5b43-4a3b-91b8-f36fc403bcc5

    HOST=$(hostname -s)
    HOST_IP=$(hostname -i)

    HOST_1=a-b-data-1
    HOST_2=a-b-data-2
    HOST_3=a-b-data-3

    HOST_1_IP=192.168.8.204
    HOST_2_IP=192.168.8.205
    HOST_3_IP=192.168.8.206

    HOST_NET=192.168.8.0/24
}

create_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        sudo mkdir -p $dir
        sudo chown ceph:ceph $dir
    fi
}

create_mon_dir() {
    create_dir /var/lib/ceph/mon/${CLUSTER}-${HOST}
}

copy_admin_keyring_and_conf() {
    sudo scp ${HOST_1}:/etc/ceph/${CLUSTER}.client.admin.keyring /etc/ceph/
    sudo scp ${HOST_1}:/etc/ceph/${CLUSTER}.conf /etc/ceph/
}

# ssh到HOST_1上执行,获取mon.keyring
get_ceph_mon_keyring() {
    ssh ${HOST_1} "sudo ceph auth get mon. -o /tmp/${CLUSTER}.mon.keyring"
}

# ssh到HOST_1上执行,获取monmap
get_monmap() {
    ssh ${HOST_1} "sudo ceph mon getmap -o /tmp/monmap"
    ssh ${HOST_1} "sudo monmaptool --add ${HOST_2} ${HOST_2_IP} --fsid $FSID /tmp/monmap"
    ssh ${HOST_1} "sudo monmaptool --add ${HOST_3} ${HOST_3_IP} --fsid $FSID /tmp/monmap"
}

# ssh到HOST_1上执行,插入更新过的monmap
inject_monmap() {
    ssh ${HOST_1} "sudo systemctl stop ceph-mon@${HOST_1}"
    ssh ${HOST_1} "sudo ceph-mon -i ${HOST_1} --inject-monmap /tmp/monmap"
    ssh ${HOST_1} "sudo systemctl start ceph-mon@${HOST_1}"
}

# 在本地创建 monitor 数据目录
ceph_mon_mkfs() {
    #sudo ceph mon getmap -o /tmp/monmap
    #sudo ceph auth get mon. -o /tmp/${CLUSTER}.mon.keyring
    sudo scp ${HOST_1}:/tmp/monmap /tmp/monmap
    sudo scp ${HOST_1}:/tmp/ceph.mon.keyring /tmp/ceph.mon.keyring

    sudo -u ceph ceph-mon --mkfs -i ${HOST} --monmap /tmp/monmap --keyring /tmp/${CLUSTER}.mon.keyring
}

start_ceph() {
    sudo systemctl start ceph-mon@${HOST}
    sudo systemctl enable ceph-mon@${HOST}
}

ceph_env
create_mon_dir
copy_admin_keyring_and_conf
get_ceph_mon_keyring
get_monmap
inject_monmap
ceph_mon_mkfs
start_ceph
