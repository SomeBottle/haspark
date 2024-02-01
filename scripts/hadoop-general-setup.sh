#!/bin/bash

# Hadoop常规初始化/初启动脚本

if [ -e $INIT_FLAG_FILE ]; then
    # 仅在容器初次启动时执行
    # 修改配置文件
    # 修改core-site.xml
    sed -i "s/%%HADOOP_MASTER%%/$HADOOP_MASTER/g" $HADOOP_CONF_DIR/core-site.xml
    # 修改hdfs-site.xml
    sed -i "s/%%HDFS_REPLICATION%%/$HDFS_REPLICATION/g" $HADOOP_CONF_DIR/hdfs-site.xml
    # 修改yarn-site.xml
    sed -i "s/%%YARN_RM_NODE%%/$YARN_RM_NODE/g" $HADOOP_CONF_DIR/yarn-site.xml

    # 修改workers文件
    for worker in $HADOOP_WORKERS; do
        echo $worker >>$HADOOP_CONF_DIR/workers
    done
    # 初始化HDFS
    echo "Formatting HDFS..."
    hdfs namenode -format
fi

# ***************** Hadoop组件启动逻辑 *****************
# ####### HDFS部分 #######
if [[ "$HDFS_LAUNCH_ON_STARTUP" == "true" ]]; then
    # 如果本机为Hadoop HDFS的master，则启动NameNode
    if [[ "$HADOOP_MASTER" == "$(hostname)" ]]; then
        echo "Starting HDFS NameNode on $(hostname)..."
        hdfs --daemon start namenode # 启动namenode
        # 如果配置了DN_ON_MASTER，则还在本节点启动DataNode
        if [[ "$DN_ON_MASTER" == "true" ]]; then
            echo "Starting DataNode on $(hostname)..."
            hdfs --daemon start datanode # 常规模式启动datanode
        fi
    fi
    # 如果本机为工作结点，启动DataNode
    # 用通配符判断本机主机名是否在HADOOP_WORKERS中
    if [[ "$HADOOP_WORKERS" == *$(hostname)* ]]; then
        # HADOOP_WORKERS中肯定不会有HADOOP_MASTER结点
        echo "Starting DataNode on worker node $(hostname)..."
        hdfs --daemon start datanode # 常规模式启动datanode
    fi
fi

# ####### Yarn部分 #######
# 是否启动Yarn集群
if [[ "$YARN_LAUNCH_ON_STARTUP" == "true" ]]; then
    # 如果本机为Yarn的ResourceManager所在节点
    if [[ "$YARN_RM_NODE" == "$(hostname)" ]]; then
        echo "Starting Yarn ResourceManager on $(hostname)..."
        yarn --daemon start resourcemanager # 启动resourcemanager
        # 如果配置了NM_WITH_RM，则还要在此节点启动NodeManager
        if [[ "$NM_WITH_RM" == "true" ]]; then
            echo "Starting NodeManager on $(hostname)..."
            yarn --daemon start nodemanager # 启动nodemanager
        fi
    elif [[ "$SH_HOSTS" = *$(hostname)* ]]; then
        # 如果不是ResourceManager所在节点
        echo "Starting NodeManager on $(hostname)..."
        yarn --daemon start nodemanager # 启动nodemanager
    fi
fi
