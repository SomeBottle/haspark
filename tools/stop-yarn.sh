#!/bin/bash

# 停止集群中所有节点YARN的脚本
source /etc/profile

for host in $SH_HOSTS; do
    echo ============= Stopping YARN on $host ==========
    ssh root@$host "source /etc/profile; stop-yarn-local.sh"
done
