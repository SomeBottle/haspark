#!/bin/bash

TEMP_PASS_FILE="/root/temp.pass"

# 临时密码文件还存在就说明SSH公钥还没交换完毕，需要等待交换完毕后再启动Hadoop
while [ -e $TEMP_PASS_FILE ]; do
    sleep 3
done

$HADOOP_HOME/sbin/start-dfs.sh
$HADOOP_HOME/sbin/start-yarn.sh
