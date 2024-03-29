#!/bin/bash

# Hadoop常规初始化/初启动脚本

. /opt/somebottle/haspark/utils.sh # 导入工具函数

if [[ "$GN_ZOOKEEPER_START_ON_STARTUP" == "true" ]]; then
    # 容器启动时，启动Zookeeper守护进程
    $ZOOKEEPER_HOME/bin/zkServer.sh start
fi

if [ -e $INIT_FLAG_FILE ]; then
    # 仅在容器初次启动时执行
    echo "Initializing Hadoop (General)."
    # 修改配置文件
    # 因为不是高可用模式，剔除配置文件中的高可用配置
    remove_ha_conf $HADOOP_CONF_DIR/core-site.xml
    remove_ha_conf $HADOOP_CONF_DIR/yarn-site.xml
    remove_ha_conf $HADOOP_CONF_DIR/hdfs-site.xml
    remove_ha_conf $HADOOP_CONF_DIR/mapred-site.xml
    # 修改core-site.xml
    sed -i "s/%%HDFS_DEF_HOST%%/$GN_NAMENODE_HOST:8020/g" $HADOOP_CONF_DIR/core-site.xml
    # 将HDFS服务地址加入持久环境变量
    echo "export HDFS_SERVICE_ADDR='${GN_NAMENODE_HOST}:8020'" >>/etc/profile.d/sh_basics.sh
    # 修改hdfs-site.xml
    sed -i "s/%%HDFS_REPLICATION%%/$HADOOP_HDFS_REPLICATION/g" $HADOOP_CONF_DIR/hdfs-site.xml
    # 修改mapred-site.xml
    sed -i "s/%%YARN_MAP_MEMORY_MB%%/$HADOOP_MAP_MEMORY_MB/g" $HADOOP_CONF_DIR/mapred-site.xml
    sed -i "s/%%YARN_REDUCE_MEMORY_MB%%/$HADOOP_REDUCE_MEMORY_MB/g" $HADOOP_CONF_DIR/mapred-site.xml
    # 修改yarn-site.xml
    sed -i "s/%%YARN_RESOURCEMANAGER_HOST%%/$GN_RESOURCEMANAGER_HOST/g" $HADOOP_CONF_DIR/yarn-site.xml

    # 修改workers文件
    for worker in $GN_HADOOP_WORKER_HOSTS; do
        echo $worker >>$HADOOP_CONF_DIR/workers
    done
    # 初始化HDFS
    echo "Formatting HDFS..."
    if [ -z "$(ls /root/hdfs/name 2>/dev/null)" ]; then
        # 仅当NameNode目录为空时才格式化
        # nonInteractive选项保证如果已经格式化过，不会询问用户再次格式化，而是直接跳过。
        $HADOOP_HOME/bin/hdfs namenode -format -nonInteractive
    else
        echo "NameNode directory already formatted, skipping format."
    fi
fi

# ***************** Hadoop组件启动逻辑 *****************
# ####### HDFS部分 #######
if [[ "$GN_HDFS_SETUP_ON_STARTUP" == "true" ]]; then
    # 如果本机为Hadoop HDFS的master，则启动NameNode
    if [[ "$GN_NAMENODE_HOST" == "$(hostname)" ]]; then
        echo "Starting HDFS NameNode on $(hostname)..."
        echo "namenode" >>$HDFS_DAEMON_SEQ_FILE
        $HADOOP_HOME/bin/hdfs --daemon start namenode # 启动namenode
        # 如果配置了GN_DATANODE_ON_MASTER，则还在本节点启动DataNode
        if [[ "$GN_DATANODE_ON_MASTER" == "true" ]]; then
            echo "Starting DataNode on $(hostname)..."
            echo "datanode" >>$HDFS_DAEMON_SEQ_FILE
            $HADOOP_HOME/bin/hdfs --daemon start datanode # 守护模式启动datanode
        fi
    fi
    # 如果本机为工作结点，启动DataNode
    # 用通配符判断本机主机名是否在GN_HADOOP_WORKER_HOSTS中
    if [[ "$GN_HADOOP_WORKER_HOSTS" == *$(hostname)* ]]; then
        # GN_HADOOP_WORKER_HOSTS中肯定不会有GN_NAMENODE_HOST结点
        echo "Starting DataNode on worker node $(hostname)..."
        echo "datanode" >>$HDFS_DAEMON_SEQ_FILE
        $HADOOP_HOME/bin/hdfs --daemon start datanode # 常规模式启动datanode
    fi
    # 如果本机需要启动SecondaryNameNode则启动
    if [[ "$GN_SECONDARY_DATANODE_HOST" == $(hostname) ]]; then
        echo "Starting SecondaryNameNode on $(hostname)..."
        echo "secondarynamenode" >>$HDFS_DAEMON_SEQ_FILE
        $HADOOP_HOME/bin/hdfs --daemon start secondarynamenode
    fi
fi

# ####### Yarn部分 #######
# 是否启动Yarn集群
if [[ "$GN_YARN_SETUP_ON_STARTUP" == "true" ]]; then
    # 如果本机为Yarn的ResourceManager所在节点
    if [[ "$GN_RESOURCEMANAGER_HOST" == "$(hostname)" ]]; then
        echo "Starting Yarn ResourceManager on $(hostname)..."
        echo "resourcemanager" >>$YARN_DAEMON_SEQ_FILE
        $HADOOP_HOME/bin/yarn --daemon start resourcemanager # 启动resourcemanager
        # 如果配置了GN_NODEMANAGER_WITH_RESOURCEMANAGER，则还要在此节点启动NodeManager
        if [[ "$GN_NODEMANAGER_WITH_RESOURCEMANAGER" == "true" ]]; then
            echo "Starting NodeManager on $(hostname)..."
            echo "nodemanager" >>$YARN_DAEMON_SEQ_FILE
            $HADOOP_HOME/bin/yarn --daemon start nodemanager # 启动nodemanager
        fi
    elif [[ "$SH_HOSTS" = *$(hostname)* ]]; then
        # 如果不是ResourceManager所在节点
        echo "Starting NodeManager on $(hostname)..."
        echo "nodemanager" >>$YARN_DAEMON_SEQ_FILE
        $HADOOP_HOME/bin/yarn --daemon start nodemanager # 启动nodemanager
    fi
fi
