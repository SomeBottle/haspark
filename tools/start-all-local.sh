#!/bin/bash

# 启动本地的HDFS，Yarn
# 先让环境变量生效
source /etc/profile

start-dfs-local.sh
start-yarn-local.sh
