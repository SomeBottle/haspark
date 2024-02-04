#!/bin/bash

# 启动集群中所有节点的HDFS，Yarn
# 先让环境变量生效
source /etc/profile

start-dfs.sh
start-yarn.sh
