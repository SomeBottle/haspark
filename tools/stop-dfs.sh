#!/bin/bash

# 停止集群中所有节点HDFS的脚本
source /etc/profile

for host in $SH_HOSTS; do
    echo ============= Stopping HDFS on $host ==========
    ssh root@$host "source /etc/profile; stop-dfs-local.sh"
done
