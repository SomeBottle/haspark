#!/bin/bash

# 启动本地的HDFS，Yarn
# 先让环境变量生效
source /etc/profile

stop-dfs-local.sh
stop-yarn-local.sh
