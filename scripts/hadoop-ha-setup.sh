#!/bin/bash

# Hadoop高可用（HA）初始化/初启动脚本

. /opt/somebottle/haspark/utils.sh # 导入工具函数

# 高可用需要等SSH密钥交换完毕再初始化
# 构建HA的sshfence，依赖于SSH通信
while [ -e $TEMP_PASS_FILE ]; do
    sleep 1
done

# 启动Zookeeper守护进程
$ZOOKEEPER_HOME/bin/zkServer.sh start

# 协调: 等待所有结点的Zookeeper守护进程启动
wait_for_java_process_on_specified_nodes QuorumPeerMain "$SH_HOSTS"

# Zookeeper Quorum列表
zookeeper_nodes=$(join_by "$SH_HOSTS" ',' ':2181')

# **************************************************** 如果需要HDFS高可用
if [[ "$HA_HDFS_SETUP_ON_STARTUP" == "true" ]]; then

    if [ -e $INIT_FLAG_FILE ]; then
        echo "Initializing Hadoop High Availability (HA) - HDFS."
        # 仅在容器初次启动时执行 - Section 1
        # 修改配置文件
        # 需要用到高可用，这里把包裹占位符给去掉
        sed -i 's/@#HA_CONF_START#@//g; s/@#HA_CONF_END#@//g' $HADOOP_CONF_DIR/core-site.xml
        sed -i 's/@#HA_CONF_START#@//g; s/@#HA_CONF_END#@//g' $HADOOP_CONF_DIR/hdfs-site.xml

        # ***********修改core-site.xml***********
        # HDFS的NameNode的NameService名
        sed -i "s/%%HDFS_DEF_HOST%%/$HA_HDFS_NAMESERVICE/g" $HADOOP_CONF_DIR/core-site.xml
        # 修改hdfs-site.xml
        sed -i "s/%%HDFS_NAMESERVICE%%/$HA_HDFS_NAMESERVICE/g" $HADOOP_CONF_DIR/hdfs-site.xml
        sed -i "s/%%ZK_ADDRS%%/$zookeeper_nodes/g" $HADOOP_CONF_DIR/core-site.xml

        # ***********修改hdfs-site.xml***********
        # HDFS副本数
        sed -i "s/%%HDFS_REPLICATION%%/$HADOOP_HDFS_REPLICATION/g" $HADOOP_CONF_DIR/hdfs-site.xml
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
        for host in $HA_NAMENODE_HOSTS; do
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
        journal_nodes=$(join_by "$HA_JOURNALNODE_HOSTS" ';' ':8485')
        # 替换JournalNode地址列表
        sed -i "s/%%HDFS_JOURNALNODE_ADDRS%%/$journal_nodes/g" $HADOOP_CONF_DIR/hdfs-site.xml
    fi

    # ################# 容器每次启动都执行的部分 SECTION1-START #################

    # 如果JournalNode在本机上需要启动
    if [[ "$HA_JOURNALNODE_HOSTS" = *$(hostname)* ]]; then
        echo "Starting JournalNode on $(hostname)..."
        echo "journalnode" >>$HDFS_DAEMON_SEQ_FILE
        $HADOOP_HOME/bin/hdfs --daemon start journalnode # 守护模式启动journalnode
    fi

    # 协调: 等待所有结点的JournalNode启动
    wait_for_java_process_on_specified_nodes JournalNode "$HA_JOURNALNODE_HOSTS"

    # ################# 容器每次启动都执行的部分 SECTION1-END #################

    if [ -e $INIT_FLAG_FILE ]; then
        # 仅在容器初次启动时执行 - Section 2

        # ***********HDFS高可用初始化***********

        # HA_NAMENODE_HOSTS是NameNode所在的容器主机名列表
        # 这里在首个主机名对应的容器上format，然后其他容器的namenode上进行元数据同步
        namenodes_arr=($HA_NAMENODE_HOSTS) # 转换为NameNodes数组

        if [[ "${namenodes_arr[0]}" == "$(hostname)" ]]; then
            # 如果本机是第一个NameNode
            # HDFS和ZKFC的格式化只需要在namenode所在主机的其中一台执行即可
            echo "Formatting HDFS..."
            if [ -z "$(ls /root/hdfs/name 2>/dev/null)" ]; then
                # 当NameNode目录为空时才格式化
                echo "-> Formatting NameNode..."
                $HADOOP_HOME/bin/hdfs namenode -format
            elif [ -z "$(ls /root/hdfs/journal 2>/dev/null)" ]; then
                # 当JournalNode目录为空时才初始化
                echo "-> Initializing JournalNode..."
                hdfs namenode -initializeSharedEdits
            else
                echo "NameNode and JournalNode directory already formatted, skipping format."
            fi
            echo "Formatting ZKFC..."
            $HADOOP_HOME/bin/hdfs zkfc -formatZK
        elif [[ "$HA_NAMENODE_HOSTS" = *$(hostname)* ]]; then
            # 如果本机不是首个NameNode，但也是NameNode，则同步元数据
            echo "Syncing HDFS metadata..."
            $HADOOP_HOME/bin/hdfs namenode -bootstrapStandby
        fi
    fi

    # ################# 容器每次启动都执行的部分 SECTION2-START #################

    # 如果NameNode在本机上需要启动
    if [[ "$HA_NAMENODE_HOSTS" = *$(hostname)* ]]; then
        echo "Starting NameNode on $(hostname)..."
        echo "namenode" >>$HDFS_DAEMON_SEQ_FILE
        $HADOOP_HOME/bin/hdfs --daemon start namenode # 守护模式启动namenode
        echo "Starting ZKFC on $(hostname)..."
        echo "zkfc" >>$HDFS_DAEMON_SEQ_FILE
        $HADOOP_HOME/bin/hdfs --daemon start zkfc # 有namenode就需要启动ZKFC
    fi

    # 如果DataNode需要在本机上启动
    if [[ "$HA_DATANODE_HOSTS" = *$(hostname)* ]]; then
        echo "Starting DataNode on $(hostname)..."
        echo "datanode" >>$HDFS_DAEMON_SEQ_FILE
        $HADOOP_HOME/bin/hdfs --daemon start datanode # 守护模式启动datanode
    fi

    # ################# 容器每次启动都执行的部分 SECTION2-END #################

fi

#
#
#
#
#
# **************************************************** 如果需要Yarn
# 这部分主要是配置ResourceManager高可用
if [[ "$HA_YARN_SETUP_ON_STARTUP" == "true" ]]; then
    if [ -e $INIT_FLAG_FILE ]; then
        # 仅在容器初次启动时执行
        echo "Initializing Hadoop High Availability (HA) - Yarn."
        # 修改配置文件
        # 需要用到高可用，这里把包裹占位符给去掉
        sed -i 's/@#HA_CONF_START#@//g; s/@#HA_CONF_END#@//g' $HADOOP_CONF_DIR/mapred-site.xml
        sed -i 's/@#HA_CONF_START#@//g; s/@#HA_CONF_END#@//g' $HADOOP_CONF_DIR/yarn-site.xml
        # ***********修改mapred-site.xml***********
        # 分配给Map和Reduce任务的内存
        sed -i "s/%%YARN_MAP_MEMORY_MB%%/$HADOOP_MAP_MEMORY_MB/g" $HADOOP_CONF_DIR/mapred-site.xml
        sed -i "s/%%YARN_REDUCE_MEMORY_MB%%/$HADOOP_REDUCE_MEMORY_MB/g" $HADOOP_CONF_DIR/mapred-site.xml
        # ***********修改yarn-site.xml***********
        sed -i "s/%%YARN_CLUSTER_ID%%/$HA_YARN_CLUSTER_ID/g" $HADOOP_CONF_DIR/yarn-site.xml

        # 抽取重复配置字符串
        rm_repeat_conf=$(extract_repeat_conf 'RESOURCEMANAGER' $HADOOP_CONF_DIR/yarn-site.xml)
        echo "========================="
        echo "Extracted rm_repeat_conf:"
        echo -e $rm_repeat_conf
        echo "========================="
        # 生成ResourceManager逻辑名，并进行配置
        rm_id=0
        rm_name_list=""
        # 待输出的生成配置
        generated_rm_conf=""
        for host in $HA_RESOURCEMANAGER_HOSTS; do
            # ResourceManager逻辑名为rm0,rm1,rm2,...
            rm_name_list+="rm$rm_id "
            # 生成每个ResourceManager逻辑名对应的主机名配置
            generated_rm_conf+="$(echo $rm_repeat_conf | sed "s/%%RESOURCEMANAGER_NAME%%/rm${rm_id}/g" | sed "s/%%RESOURCEMANAGER_HOST%%/$host/g") \n"
            # ResourceManager id递增
            ((rm_id++))
        done
        # Namenode逻辑名列表转换为逗号分隔
        rm_name_list=$(join_by "$rm_name_list" ',')
        # 修改NameNode逻辑名列表
        sed -i "s/%%YARN_RESOURCEMANAGER_NAMES%%/$rm_name_list/g" $HADOOP_CONF_DIR/yarn-site.xml
        echo "========================="
        echo "Generated ResourceManager config: "
        echo -e $generated_rm_conf
        echo "========================="
        # 处理完成后把HA_REPEAT_XXX_START/END部分用生成的配置替换
        replace_repeat_conf 'RESOURCEMANAGER' "$generated_rm_conf" $HADOOP_CONF_DIR/yarn-site.xml
        # Zookeeper节点地址
        sed -i "s/%%ZK_ADDRS%%/$zookeeper_nodes/g" $HADOOP_CONF_DIR/yarn-site.xml
    fi

    # ################# 容器每次启动都执行的部分 SECTION-START #################

    # 如果ResourceManager在本机上需要启动
    if [[ "$HA_RESOURCEMANAGER_HOSTS" = *$(hostname)* ]]; then
        echo "Starting ResourceManager on $(hostname)..."
        echo "resourcemanager" >>$YARN_DAEMON_SEQ_FILE
        $HADOOP_HOME/bin/yarn --daemon start resourcemanager # 守护模式启动RM
    fi

    # 如果DataNode需要在本机上启动
    if [[ "$HA_NODEMANAGER_HOSTS" = *$(hostname)* ]]; then
        echo "Starting NodeManager on $(hostname)..."
        echo "nodemanager" >>$YARN_DAEMON_SEQ_FILE
        $HADOOP_HOME/bin/yarn --daemon start nodemanager # 守护模式启动NM
    fi

    # ################# 容器每次启动都执行的部分 SECTION-END #################

fi
