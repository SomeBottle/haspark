#!/bin/bash

# 启动HDFS，Yarn
# 先让环境变量生效
source /etc/profile

stop-dfs.sh
stop-yarn.sh
