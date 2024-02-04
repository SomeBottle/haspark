#!/bin/bash

# 启动集群中所有节点YARN的脚本
source /etc/profile

for host in $SH_HOSTS; do
    echo ============= Starting YARN on $host ==========
    ssh root@$host "source /etc/profile; start-yarn-local.sh"
done
