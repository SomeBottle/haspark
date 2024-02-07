# 采用bitnami/spark镜像，此镜像基于精简Debian 11系统
# 基于Spark 3.5.0版本
# 适配Hadoop 3.3+
FROM bitnami/spark:3.5.0

LABEL maintainer="somebottle <somebottle@outlook.com>"
LABEL description="Docker image with Spark 3.5.0 and Hadoop 3.3.6, based on bitnami/spark image. For my graduation project." 

# 环境变量配置
# Zookeeper版本
ENV ZOOKEEPER_VER="3.9.1"
# Zookeeper安装目录
ENV ZOOKEEPER_HOME="/opt/zookeeper"
# Zookeeper配置目录
ENV ZOOKEEPER_CONF_DIR="/opt/zookeeper/conf"
# Zookeeper数据目录
ENV ZOOKEEPER_DATA_DIR="/root/zooData"
# Hadoop版本
ENV HADOOP_VER="3.3.6" 
# Hadoop安装目录
ENV HADOOP_HOME="/opt/hadoop"
# Hadoop配置目录
ENV HADOOP_CONF_DIR="/opt/hadoop/etc/hadoop"
# Hadoop日志目录
ENV HADOOP_LOG_DIR="/opt/hadoop/logs"
# 把Hadoop目录加入环境变量
ENV PATH="$HADOOP_HOME/bin:/opt/somebottle/haspark/tools:$ZOOKEEPER_HOME/bin:$PATH"
# 把Hadoop本地库加入动态链接库路径
# 以免Spark或Hadoop找不到Hadoop Native Library
ENV LD_LIBRARY_PATH="$HADOOP_HOME/lib/native:$LD_LIBRARY_PATH"
# 临时密码文件路径加入环境变量
ENV TEMP_PASS_FILE="/root/temp.pass"
# 用户.ssh配置目录
ENV USR_SSH_CONF_DIR="/root/.ssh"
# 容器初次启动标识文件
ENV INIT_FLAG_FILE="/root/init_flag"
# 以下是一些环境变量默认值，用于Hadoop初始化
ENV HADOOP_LAUNCH_MODE="general"
ENV HADOOP_HDFS_REPLICATION="2"
ENV HADOOP_MAP_MEMORY_MB="1024"
ENV HADOOP_REDUCE_MEMORY_MB="1024"
ENV GN_DATANODE_ON_MASTER="false"
ENV GN_NODEMANAGER_WITH_RESOURCEMANAGER="false"
ENV GN_NODEMANAGER_WITH_RESOURCEMANAGER="false"
ENV GN_HDFS_SETUP_ON_STARTUP="false"
ENV GN_YARN_SETUP_ON_STARTUP="false"
ENV HA_HDFS_NAMESERVICE="hacluster"
ENV HA_HDFS_SETUP_ON_STARTUP="false"
ENV HA_YARN_SETUP_ON_STARTUP="false"

# 以Root用户完成
USER root

# 复制镜像源
COPY resources/sources.list /tmp/sources.list

# 将路径环境变量写入/etc/profile.d/path_env.sh
RUN echo -e "#!/bin/bash\nexport PATH=$PATH\nexport LD_LIBRARY_PATH=$LD_LIBRARY_PATH" > /etc/profile.d/path_env.sh && \
    # 将Hadoop部分环境变量写入/etc/profile.d/hadoop.sh
    echo -e "#!/bin/bash\nexport HADOOP_HOME=$HADOOP_HOME\nexport HADOOP_CONF_DIR=$HADOOP_CONF_DIR" >> /etc/profile.d/hadoop.sh && \ 
    # 创建容器启动标识文件
    touch $INIT_FLAG_FILE && \
    # 先生成一个临时SSH密码，用于首次启动时交换ssh密钥
    echo $(openssl rand -base64 32) > $TEMP_PASS_FILE && \
    # 修改root用户的密码
    echo -e "$(cat $TEMP_PASS_FILE)\n$(cat $TEMP_PASS_FILE)" | passwd root && \
    # 若.ssh目录不存在则建立
    [ -d $USR_SSH_CONF_DIR ] || mkdir -p $USR_SSH_CONF_DIR && \
    # 建立SSH公钥交换标记目录
    mkdir -p $USR_SSH_CONF_DIR/exchange_flags && \
    # 更换镜像源
    mv /tmp/sources.list /etc/apt/sources.list && \
    # 更新apt-get以及openssh-server, wget, vim, sshpass, net-tools, psmisc
    # psmisc包含Hadoop HA - sshfence所需的fuser工具
    apt-get update && apt-get install -y openssh-server wget vim sshpass lsof net-tools psmisc rsync zip && \
    # 建立haspark脚本目录
    mkdir -p /opt/somebottle/haspark && \
    # 建立工具脚本目录
    mkdir -p /opt/somebottle/haspark/tools && \
    # 建立临时配置目录
    mkdir /tmp/tmp_configs


# 切换到安装目录/opt
WORKDIR /opt

# 拷贝配置文件
COPY configs/* /tmp/tmp_configs/  
# 拷贝启动脚本
COPY scripts/* /opt/somebottle/haspark
# 拷贝工具脚本
COPY tools/* /opt/somebottle/haspark/tools/

# 下载Hadoop并解压至/opt/hadoop，使用清华镜像
RUN wget https://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-${HADOOP_VER}/hadoop-${HADOOP_VER}.tar.gz && \
    tar -zxf hadoop-${HADOOP_VER}.tar.gz && \
    mv hadoop-${HADOOP_VER} hadoop && \
    rm -f hadoop-${HADOOP_VER}.tar.gz && \
    # 移动配置文件到对应目录
    mv /tmp/tmp_configs/core-site.xml ${HADOOP_CONF_DIR}/core-site.xml && \
    mv /tmp/tmp_configs/hdfs-site.xml ${HADOOP_CONF_DIR}/hdfs-site.xml && \
    mv /tmp/tmp_configs/mapred-site.xml ${HADOOP_CONF_DIR}/mapred-site.xml && \
    mv /tmp/tmp_configs/yarn-site.xml ${HADOOP_CONF_DIR}/yarn-site.xml && \
    mv /tmp/tmp_configs/hadoop-env.sh ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    mv /tmp/tmp_configs/workers ${HADOOP_CONF_DIR}/workers && \
    mv /tmp/tmp_configs/ssh_config $USR_SSH_CONF_DIR/config && \
    mv /tmp/tmp_configs/sshd_config /etc/ssh/sshd_config && \
    rm -rf /tmp/tmp_configs && \
    # 下载Zookeeper并解压至/opt/zookeeper
    wget https://mirrors.tuna.tsinghua.edu.cn/apache/zookeeper/zookeeper-${ZOOKEEPER_VER}/apache-zookeeper-${ZOOKEEPER_VER}-bin.tar.gz && \
    tar -zxf apache-zookeeper-${ZOOKEEPER_VER}-bin.tar.gz && \
    mv apache-zookeeper-${ZOOKEEPER_VER}-bin zookeeper && \
    rm -f apache-zookeeper-${ZOOKEEPER_VER}-bin.tar.gz && \
    # 拷贝Zookeeper基础配置文件
    cp /opt/zookeeper/conf/zoo_sample.cfg /opt/zookeeper/conf/zoo.cfg && \
    # 修改Zookeeper数据目录
    sed -i "s|dataDir=/tmp/zookeeper|dataDir=$ZOOKEEPER_DATA_DIR|" /opt/zookeeper/conf/zoo.cfg && \
    # 建立Zookeeper数据目录
    mkdir -p $ZOOKEEPER_DATA_DIR && \
    # 调整.ssh目录下文件权限
    chmod 600 $USR_SSH_CONF_DIR/config && \
    chmod 700 $USR_SSH_CONF_DIR && \
    # 建立HDFS目录以及工具脚本目录
    mkdir -p /root/hdfs/name && \ 
    mkdir -p /root/hdfs/data && \
    mkdir -p /root/hdfs/journal && \
    # 增加执行权限
    chmod +x /opt/somebottle/haspark/*.sh && \
    chmod +x $HADOOP_HOME/sbin/*.sh && \
    chmod +x $ZOOKEEPER_HOME/bin/*.sh && \
    # 给所有工具脚本加上可执行权限
    chmod +x /opt/somebottle/haspark/tools/*

# 替换JSch库
COPY lib/jsch-0.2.16.jar /opt/hadoop/share/hadoop/hdfs/lib/jsch-0.1.55.jar
COPY lib/jsch-0.2.16.jar /opt/hadoop/share/hadoop/common/lib/jsch-0.1.55.jar

# 容器启动待执行的脚本
ENTRYPOINT [ "/opt/somebottle/haspark/entry.sh" ]