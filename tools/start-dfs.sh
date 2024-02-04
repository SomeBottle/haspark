#!/bin/bash

# 启动集群中所有节点HDFS的脚本
source /etc/profile

for host in $SH_HOSTS; do
    echo ============= Starting HDFS on $host ==========
    ssh root@$host "source /etc/profile; start-dfs-local.sh"
done
