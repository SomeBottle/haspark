#!/bin/bash

# Hadoop常规初始化/初启动脚本

if [ -e $INIT_FLAG_FILE ]; then
    # 仅在容器初次启动时执行
    echo "Initializing Hadoop (General)."
    # 修改配置文件
    # 因为不是高可用模式，剔除配置文件中的高可用配置
    sed -i '/@#HA_CONF_START#@/,/@#HA_CONF_END#@/d' $HADOOP_CONF_DIR/core-site.xml
    sed -i '/@#HA_CONF_START#@/,/@#HA_CONF_END#@/d' $HADOOP_CONF_DIR/yarn-site.xml
    sed -i '/@#HA_CONF_START#@/,/@#HA_CONF_END#@/d' $HADOOP_CONF_DIR/hdfs-site.xml
    sed -i '/@#HA_CONF_START#@/,/@#HA_CONF_END#@/d' $HADOOP_CONF_DIR/mapred-site.xml
    # 修改core-site.xml
    sed -i "s/%%HDFS_DEF_HOST%%/$HADOOP_MASTER:8020/g" $HADOOP_CONF_DIR/core-site.xml
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
            hdfs --daemon start datanode # 守护模式启动datanode
        fi
    fi
    # 如果本机为工作结点，启动DataNode
    # 用通配符判断本机主机名是否在HADOOP_WORKERS中
    if [[ "$HADOOP_WORKERS" == *$(hostname)* ]]; then
        # HADOOP_WORKERS中肯定不会有HADOOP_MASTER结点
        echo "Starting DataNode on worker node $(hostname)..."
        hdfs --daemon start datanode # 常规模式启动datanode
    fi
    # 如果本机需要启动SecondaryNameNode则启动
    if [[ "$SECONDARY_DN_NODE" == $(hostname) ]]; then
        echo "Starting SecondaryNameNode on $(hostname)..."
        hdfs --daemon start secondarynamenode
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
