#!/bin/bash

# Hadoop初始化/初启动脚本

# 修改配置文件
# 修改core-site.xml
sed -i "s/%%HADOOP_MASTER%%/$HADOOP_MASTER/g" $HADOOP_CONF_DIR/core-site.xml
# 修改hdfs-site.xml
sed -i "s/%%HDFS_REPLICATION%%/$HDFS_REPLICATION/g" $HADOOP_CONF_DIR/hdfs-site.xml
# 修改yarn-site.xml
sed -i "s/%%YARN_RM_NODE%%/$YARN_RM_NODE/g" $HADOOP_CONF_DIR/yarn-site.xml

# 修改workers文件
for worker in $HADOOP_WORKERS; do
    echo $worker >> $HADOOP_CONF_DIR/workers
done


# 如果本机为Hadoop HDFS的master，则启动HDFS
if [ "$HADOOP_MASTER" = "$(hostname)" ]; then
    # 在主容器下启动 Hadoop
    # 读取环境变量，是否启动Hadoop HDFS组件
    if [[ -z "$HDFS_LAUNCH_ON_STARTUP" || "$HDFS_LAUNCH_ON_STARTUP" != "false" ]]; then
        echo "Starting HDFS NameNode..."
        hdfs namenode # 启动namenode
        # 如果配置了DN_ON_MASTER，则启动DataNode
        if [ "$DN_ON_MASTER" = "true" ]; then
            echo "Starting DataNode on master..."
            hdfs datanode -regular # 常规模式启动datanode
        fi
    fi
else
    echo "This node is not a Hadoop HDFS master."
fi

# 如果本机为Yarn的master
if [ "$YARN_RM_NODE" = "$(hostname)" ]; then
    # 是否启动Yarn集群
    if [[ -z "$YARN_LAUNCH_ON_STARTUP" || "$YARN_LAUNCH_ON_STARTUP" != "false" ]]; then
        echo "Starting Yarn ResourceManager..."
        yarn resourcemanager # 启动resourcemanager
        # 如果配置了NM_WITH_RM，则启动NodeManager
        if [ "$NM_WITH_RM" = "true" ]; then
            echo "Starting NodeManager..."
            yarn nodemanager # 启动nodemanager
        fi
    fi
else
    echo "This node is not a Hadoop Yarn master."
fi

# 如果本机为工作结点，启动NodeManager和DataNode
# 用通配符判断本机主机名是否在HADOOP_WORKERS中
if [[ "$HADOOP_WORKERS" == *$(hostname)* ]]; then
    # 是否启动NodeManager
    if [[ -z "$YARN_LAUNCH_ON_STARTUP" || "$YARN_LAUNCH_ON_STARTUP" != "false" ]]; then
        echo "Starting NodeManager..."
        yarn nodemanager # 启动nodemanager
    fi
    # 是否启动DataNode
    if [[ -z "$HDFS_LAUNCH_ON_STARTUP" || "$HDFS_LAUNCH_ON_STARTUP" != "false" ]]; then
        echo "Starting DataNode..."
        hdfs datanode -regular # 常规模式启动datanode
    fi
fi
