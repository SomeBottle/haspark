# 采用bitnami/spark镜像，此镜像基于精简Debian 11系统
# 基于Spark 3.5.0版本
# 适配Hadoop 3.3+
FROM bitnami/java:11.0.23-10 AS openjdk

FROM bitnami/spark:3.5.0

LABEL maintainer="somebottle <somebottle@outlook.com>" \
    description="Docker image with Spark 3.5.0 and Hadoop 3.3.6, based on bitnami/spark image. For my graduation project." 

# 环境变量配置
# Zookeeper版本
ENV ZOOKEEPER_VER="3.9.2" \
    # Zookeeper安装目录
    ZOOKEEPER_HOME="/opt/zookeeper" \
    # Zookeeper配置目录
    ZOOKEEPER_CONF_DIR="/opt/zookeeper/conf" \
    # Zookeeper数据目录
    ZOOKEEPER_DATA_DIR="/root/zooData" \
    # Hadoop版本
    HADOOP_VER="3.3.6" \
    # Hadoop安装目录
    HADOOP_HOME="/opt/hadoop" \
    # Hadoop配置目录
    HADOOP_CONF_DIR="/opt/hadoop/etc/hadoop" \
    # Hadoop日志目录
    HADOOP_LOG_DIR="/opt/hadoop/logs"
# 用户.ssh配置目录
ENV USR_SSH_CONF_DIR="/root/.ssh" \
    # 容器初次启动标识文件
    INIT_FLAG_FILE="/root/init_flag" \
    # 定义PATH
    HASPARK_PATH="$HADOOP_HOME/bin:/opt/somebottle/haspark/tools:$ZOOKEEPER_HOME/bin" \
    HASPARK_LD_LIBRARY_PATH="$HADOOP_HOME/lib/native"
# 把Hadoop目录加入环境变量
ENV PATH="$HASPARK_PATH:$PATH" \
    # 把Hadoop本地库加入动态链接库路径
    # 以免Spark或Hadoop找不到Hadoop Native Library
    LD_LIBRARY_PATH="$HASPARK_LD_LIBRARY_PATH:$LD_LIBRARY_PATH" \
    # 临时密码文件路径加入环境变量
    TEMP_PASS_FILE="/root/temp.pass" \
    # 保留 Bitnami 的环境变量
    BITNAMI_PATHS="/opt/bitnami/python/bin:/opt/bitnami/java/bin:/opt/bitnami/spark/bin:/opt/bitnami/spark/sbin"
# 以下是一些环境变量默认值，用于Hadoop初始化
ENV HADOOP_LAUNCH_MODE="general" \
    HADOOP_HDFS_REPLICATION="2" \
    HADOOP_MAP_MEMORY_MB="1024" \
    HADOOP_REDUCE_MEMORY_MB="1024" \
    GN_DATANODE_ON_MASTER="false" \
    GN_NODEMANAGER_WITH_RESOURCEMANAGER="false" \
    GN_NODEMANAGER_WITH_RESOURCEMANAGER="false" \
    GN_HDFS_SETUP_ON_STARTUP="false" \
    GN_YARN_SETUP_ON_STARTUP="false" \
    GN_ZOOKEEPER_START_ON_STARTUP="false" \
    HA_HDFS_NAMESERVICE="hacluster" \
    HA_HDFS_SETUP_ON_STARTUP="false" \
    HA_YARN_SETUP_ON_STARTUP="false" 

# 以Root用户完成
USER root

# 复制镜像源
COPY resources/sources.list /tmp/sources.list

# 将路径环境变量写入/etc/profile.d/path_env.sh
RUN echo -e "#!/bin/bash\nexport PATH=$HASPARK_PATH:\$PATH\nexport LD_LIBRARY_PATH=$HASPARK_LD_LIBRARY_PATH:\$LD_LIBRARY_PATH" > /etc/profile.d/path_env.sh && \
    # 将Bitnami环境变量写入/etc/profile.d/bitnami.sh
    echo -e "#!/bin/bash\nexport PATH=$BITNAMI_PATHS:\$PATH" > /etc/profile.d/bitnami.sh && \
    # 将Hadoop部分环境变量写入/etc/profile.d/hadoop.sh
    echo -e "#!/bin/bash\nexport HADOOP_HOME=$HADOOP_HOME\nexport HADOOP_CONF_DIR=$HADOOP_CONF_DIR\nexport HADOOP_LOG_DIR=$HADOOP_LOG_DIR\nexport HADOOP_VER=$HADOOP_VER" >> /etc/profile.d/hadoop.sh && \ 
    # 将Zookeeper部分环境变量写入/etc/profile.d/zookeeper.sh
    echo -e "#!/bin/bash\nexport ZOOKEEPER_HOME=$ZOOKEEPER_HOME\nexport ZOOKEEPER_CONF_DIR=$ZOOKEEPER_CONF_DIR\nexport ZOOKEEPER_VER=$ZOOKEEPER_VER\nexport ZOOKEEPER_DATA_DIR=$ZOOKEEPER_DATA_DIR" >> /etc/profile.d/zookeeper.sh && \
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
    rm -rf /var/lib/apt/lists/* && \
    # 清除下载的deb包
    apt-get clean && \
    # 建立haspark脚本目录
    mkdir -p /opt/somebottle/haspark && \
    # 建立工具脚本目录
    mkdir -p /opt/somebottle/haspark/tools && \
    # 建立临时配置目录
    mkdir /tmp/tmp_configs && \
    # 移除镜像中的 OpenJDK 17 
    rm -rf /opt/bitnami/java

# 把 Java 更换为 OpenJDK 11，因为 Hadoop 尚未支持运行时 Java 17，可能出现问题。

COPY --from=openjdk /opt/bitnami/java /opt/bitnami/java

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
    # 删除hadoop的docs，可以省下很多空间
    rm -rf ${HADOOP_HOME}/share/doc && \
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
    # 删除zookeeper的docs
    rm -rf ${ZOOKEEPER_HOME}/docs && \
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