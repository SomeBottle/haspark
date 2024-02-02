#!/bin/bash

# Hadoop高可用（HA）初始化/初启动脚本

. /opt/utils.sh # 导入工具函数

# 高可用需要等SSH密钥交换完毕再初始化
# 构建HA的sshfence，依赖于SSH通信
while [ -e $TEMP_PASS_FILE ]; do
    sleep 3
done

# 启动Zookeeper守护进程
$ZOOKEEPER_HOME/bin/zkServer.sh start

# 协调: 等待所有结点的Zookeeper守护进程启动
wait_for_java_process_on_specified_nodes QuorumPeerMain "$SH_HOSTS"

if [ -e $INIT_FLAG_FILE ]; then
    echo "Initializing Hadoop High Availability (HA)."
    # 仅在容器初次启动时执行 - Section 1
    # 修改配置文件
    # 需要用到高可用，这里把包裹占位符给去掉
    sed -i 's/@#HA_CONF_START#@//g; s/@#HA_CONF_END#@//g' $HADOOP_CONF_DIR/core-site.xml
    sed -i 's/@#HA_CONF_START#@//g; s/@#HA_CONF_END#@//g' $HADOOP_CONF_DIR/hdfs-site.xml
    sed -i 's/@#HA_CONF_START#@//g; s/@#HA_CONF_END#@//g' $HADOOP_CONF_DIR/mapred-site.xml
    sed -i 's/@#HA_CONF_START#@//g; s/@#HA_CONF_END#@//g' $HADOOP_CONF_DIR/yarn-site.xml

    # ***********修改core-site.xml***********
    # HDFS的NameNode的NameService名
    sed -i "s/%%HDFS_DEF_HOST%%/$HA_HDFS_NAMESERVICE/g" $HADOOP_CONF_DIR/core-site.xml
    # 修改hdfs-site.xml
    sed -i "s/%%HDFS_NAMESERVICE%%/$HA_HDFS_NAMESERVICE/g" $HADOOP_CONF_DIR/hdfs-site.xml
    # Zookeeper Quorum列表
    zookeeper_nodes=$(join_by "$SH_HOSTS" ',' ':2181')
    sed -i "s/%%ZOOKEEPER_NODES%%/$zookeeper_nodes/g" $HADOOP_CONF_DIR/core-site.xml

    # ***********修改hdfs-site.xml***********
    # HDFS副本数
    sed -i "s/%%HDFS_REPLICATION%%/$HDFS_REPLICATION/g" $HADOOP_CONF_DIR/hdfs-site.xml
    # HDFS的NameNode的NameService名
    sed -i "s/%%HDFS_NAMESERVICE%%/$HA_HDFS_NAMESERVICE/g" $HADOOP_CONF_DIR/hdfs-site.xml
    # 抽取重复配置字符串
    namenode_repeat_conf=$(extract_repeat_conf 'NAMENODE' $HADOOP_CONF_DIR/hdfs-site.xml)
    echo "========================="
    echo "Extracted namenode_repeat_conf:"
    echo -e $namenode_repeat_conf
    echo "========================="
    # 生成Namenode逻辑名，并进行配置
    namenode_id=0
    namenodes_name_list=""
    # 待输出的生成配置
    generated_namenodes_conf=""
    for host in $NAMENODE_NODES; do
        # namenode逻辑名为nn0,nn1,nn2,...
        namenodes_name_list+="nn$namenode_id "
        # 生成每个namenode逻辑名对应的主机名配置
        generated_namenodes_conf+="$(echo $namenode_repeat_conf | sed "s/%%NAMENODE_NAME%%/nn${namenode_id}/g" | sed "s/%%NAMENODE_HOST%%/$host/g") \n"
        # namenode id递增
        ((namenode_id++))
    done
    # Namenode逻辑名列表转换为逗号分隔
    namenodes_name_list=$(join_by "$namenodes_name_list" ',')
    # 修改NameNode逻辑名列表
    sed -i "s/%%HDFS_NAMENODE_NAMES%%/$namenodes_name_list/g" $HADOOP_CONF_DIR/hdfs-site.xml
    echo "========================="
    echo "Generated Namenodes config: "
    echo -e $generated_namenodes_conf
    echo "========================="
    # 处理完成后把HA_REPEAT_XXX_START/END部分用生成的配置替换
    replace_repeat_conf 'NAMENODE' "$generated_namenodes_conf" $HADOOP_CONF_DIR/hdfs-site.xml
    # 生成JournalNode地址列表
    journal_nodes=$(join_by "$JOURNALNODE_NODES" ';' ':8485')
    # 替换JournalNode地址列表
    sed -i "s/%%JOURNALNODE_NODES%%/$journal_nodes/g" $HADOOP_CONF_DIR/hdfs-site.xml
fi





# ################# 容器每次启动都执行的部分 SECTION1-START #################

# 如果JournalNode在本机上需要启动
if [[ "$JOURNALNODE_NODES" = *$(hostname)* ]]; then
    echo "Starting JournalNode on $(hostname)..."
    hdfs --daemon start journalnode # 守护模式启动journalnode
fi

# 协调: 等待所有结点的JournalNode启动
wait_for_java_process_on_specified_nodes JournalNode "$JOURNALNODE_NODES"

# ################# 容器每次启动都执行的部分 SECTION1-END #################




if [ -e $INIT_FLAG_FILE ]; then
    # 仅在容器初次启动时执行 - Section 2

    # ***********HDFS高可用初始化***********

    # NAMENODE_NODES是NameNode所在的容器主机名列表
    # 这里在首个主机名对应的容器上format，然后其他容器的namenode上进行元数据同步
    namenodes_arr=($NAMENODE_NODES) # 转换为NameNodes数组

    if [[ "${namenodes_arr[0]}" == "$(hostname)" ]]; then
        # 如果本机是第一个NameNode
        # HDFS和ZKFC的格式化只需要在namenode所在主机的其中一台执行即可
        echo "Formatting HDFS..."
        hdfs namenode -format
        echo "Formatting ZKFC..."
        hdfs zkfc -formatZK
    elif [[ "$NAMENODE_NODES" = *$(hostname)* ]]; then
        # 如果本机不是首个NameNode，但也是NameNode，则同步元数据
        echo "Syncing HDFS metadata..."
        hdfs namenode -bootstrapStandby
    fi
fi





# ################# 容器每次启动都执行的部分 SECTION2-START #################

# 如果NameNode在本机上需要启动
if [[ "$NAMENODE_NODES" = *$(hostname)* ]]; then
    echo "Starting NameNode on $(hostname)..."
    hdfs --daemon start namenode # 守护模式启动namenode
    echo "Starting ZKFC on $(hostname)..."
    hdfs --daemon start zkfc # 有namenode就需要启动ZKFC
fi

# Todo: 能配置是否初始化并启动HDFS/YARN，然后另外还要配置ZKFC
# 另外还要考虑DataNode和其他一些进程如何启动.

# ################# 容器每次启动都执行的部分 SECTION2-END #################
