#!/bin/bash

# 停止集群中所有节点的HDFS，Yarn
# 先让环境变量生效
source /etc/profile

stop-dfs.sh
stop-yarn.sh
