#!/bin/bash

# Hadoop高可用（HA）初始化/初启动脚本

. /opt/utils.sh # 导入工具函数

# 高可用需要等SSH密钥交换完毕再初始化
while [ -e $TEMP_PASS_FILE ]; do
    sleep 3
done

if [ -e $INIT_FLAG_FILE ]; then
    # 仅在容器初次启动时执行
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
    zookeeper_nodes=$(join_by "$SH_HOSTS" ',' ':2888')
    sed -i "s/%%ZOOKEEPER_NODES%%/$zookeeper_nodes/g" $HADOOP_CONF_DIR/core-site.xml

    # ***********修改hdfs-site.xml***********
    # HDFS副本数
    sed -i "s/%%HDFS_REPLICATION%%/$HDFS_REPLICATION/g" $HADOOP_CONF_DIR/hdfs-site.xml
    # HDFS的NameNode的NameService名
    sed -i "s/%%HDFS_NAMESERVICE%%/$HA_HDFS_NAMESERVICE/g" $HADOOP_CONF_DIR/hdfs-site.xml
    # 抽取重复配置字符串
    namenode_repeat_conf=$(extract_repeat_conf 'NAMENODE' $HADOOP_CONF_DIR/hdfs-site.xml)
    # 生成Namenode逻辑名，并进行配置
    namenode_id=0
    namenodes_name_list=""
    # 待输出的生成配置
    generated_namenodes_conf=""
    for host in $NAMENODE_NODES; do
        # namenode逻辑名为nn0,nn1,nn2,...
        namenodes_name_list+="nn$namenode_id "
        # 生成每个namenode逻辑名对应的主机名配置
        generated_namenodes_conf+=$(echo $namenode_repeat_conf | sed "s/%%NAMENODE_NAME%%/nn${namenode_id}/g" | sed "s/%%NAMENODE_HOST%%/$host/g") '\n'
    done
    # Namenode逻辑名列表转换为逗号分隔
    namenodes_name_list=$(join_by "$namenodes_name_list" ',')
    # 修改NameNode逻辑名列表
    sed -i "s/%%HDFS_NAMENODE_NAMES%%/$namenodes_name_list/g" $HADOOP_CONF_DIR/hdfs-site.xml
    # 处理完成后把HA_REPEAT_XXX_START/END部分用生成的配置替换
    replace_repeat_conf 'NAMENODE' "$generated_namenodes_conf" $HADOOP_CONF_DIR/hdfs-site.xml
    # 生成JournalNode地址列表
    journal_nodes=$(join_by "$JOURNALNODE_NODES" ';' ':8485')
    # 替换JournalNode地址列表
    sed -i "s/%%JOURNALNODE_NODES%%/$journal_nodes/g" $HADOOP_CONF_DIR/hdfs-site.xml
fi
