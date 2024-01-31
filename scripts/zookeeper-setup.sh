#!/bin/bash

# Zookeeper初始化脚本
echo "Cluster hosts: $SH_HOSTS"
echo "My host: $(hostname)"

if [ -e $INIT_FLAG_FILE ]; then
    # 首次启动容器时进行初始化
    ID=0
    MY_ID=0
    for host in $SH_HOSTS; do
        if [ $host == "$(hostname)" ]; then
            MY_ID=$ID # 找到本容器对应的myid
        fi
        # 节点通信端口2888，Leader选举通信端口3888
        echo "server.$ID=$host:2888:3888" >>$ZOOKEEPER_CONF_DIR/zoo.cfg
        ((ID++))
    done
    echo "Myid: $MY_ID"
    # 生成本节点的myid
    echo $MY_ID >$ZOOKEEPER_DATA_DIR/myid
fi
