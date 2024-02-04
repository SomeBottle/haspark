# 采用bitnami/spark镜像，此镜像基于精简Debian 11系统
# 基于Spark 3.5.0版本
# 适配Hadoop 3.3+
FROM bitnami/spark:3.5.0

LABEL maintainer="somebottle <somebottle@gmail.com>"
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
# 临时密码文件路径加入环境变量
ENV TEMP_PASS_FILE="/root/temp.pass"
# 用户.ssh配置目录
ENV USR_SSH_CONF_DIR="/root/.ssh"
# Hadoop HDFS是否随容器一并启动
ENV GN_HDFS_SETUP_ON_STARTUP="true"
# Hadoop YARN是否随容器一并启动
ENV GN_YARN_SETUP_ON_STARTUP="true"
# 容器初次启动标识文件
ENV INIT_FLAG_FILE="/root/init_flag"
# 高可用-HDFS Nameservice
ENV HA_HDFS_NAMESERVICE="hacluster"

# 以Root用户完成
USER root

# 将环境变量写入/etc/profile.d/container_env.sh
RUN echo -e '#!/bin/bash\nexport PATH='$PATH > /etc/profile.d/container_env.sh

# 创建容器启动标识文件
RUN touch $INIT_FLAG_FILE

# 先生成一个临时SSH密码，用于首次启动时交换ssh密钥
RUN echo $(openssl rand -base64 32) > $TEMP_PASS_FILE
# 修改root用户的密码
RUN echo -e "$(cat $TEMP_PASS_FILE)\n$(cat $TEMP_PASS_FILE)" | passwd root 


# 若.ssh目录不存在则建立
RUN [ -d $USR_SSH_CONF_DIR ] || mkdir -p $USR_SSH_CONF_DIR
# 建立标记目录
RUN mkdir -p $USR_SSH_CONF_DIR/exchange_flags

# 更换镜像源
COPY resources/sources.list /tmp/sources.list
RUN mv /tmp/sources.list /etc/apt/sources.list

# 更新apt-get以及openssh-server, wget, vim, sshpass, net-tools, psmisc
# psmisc包含Hadoop HA - sshfence所需的fuser工具
RUN apt-get update && apt-get install -y openssh-server wget vim sshpass lsof net-tools psmisc

# 建立haspark脚本目录
RUN mkdir -p /opt/somebottle/haspark

# 切换到安装目录/opt
WORKDIR /opt
# 下载Hadoop并解压至/opt/hadoop，使用清华镜像
RUN wget https://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-${HADOOP_VER}/hadoop-${HADOOP_VER}.tar.gz \
    && tar -zxf hadoop-${HADOOP_VER}.tar.gz \
    && mv hadoop-${HADOOP_VER} hadoop \
    && rm -f hadoop-${HADOOP_VER}.tar.gz

# 临时配置目录
RUN mkdir /tmp/tmp_configs

# 拷贝配置文件
COPY configs/* /tmp/tmp_configs/  

# 移动配置文件到对应目录
RUN mv /tmp/tmp_configs/core-site.xml ${HADOOP_CONF_DIR}/core-site.xml \
    && mv /tmp/tmp_configs/hdfs-site.xml ${HADOOP_CONF_DIR}/hdfs-site.xml \
    && mv /tmp/tmp_configs/mapred-site.xml ${HADOOP_CONF_DIR}/mapred-site.xml \
    && mv /tmp/tmp_configs/yarn-site.xml ${HADOOP_CONF_DIR}/yarn-site.xml \
    && mv /tmp/tmp_configs/hadoop-env.sh ${HADOOP_CONF_DIR}/hadoop-env.sh \
    && mv /tmp/tmp_configs/workers ${HADOOP_CONF_DIR}/workers \
    && mv /tmp/tmp_configs/ssh_config $USR_SSH_CONF_DIR/config \
    && mv /tmp/tmp_configs/sshd_config /etc/ssh/sshd_config \
    && rm -rf /tmp/tmp_configs

# 下载Zookeeper并解压至/opt/zookeeper
RUN wget https://mirrors.tuna.tsinghua.edu.cn/apache/zookeeper/zookeeper-${ZOOKEEPER_VER}/apache-zookeeper-${ZOOKEEPER_VER}-bin.tar.gz \
    && tar -zxf apache-zookeeper-${ZOOKEEPER_VER}-bin.tar.gz \
    && mv apache-zookeeper-${ZOOKEEPER_VER}-bin zookeeper \
    && rm -f apache-zookeeper-${ZOOKEEPER_VER}-bin.tar.gz

# 拷贝Zookeeper基础配置文件
RUN cp /opt/zookeeper/conf/zoo_sample.cfg /opt/zookeeper/conf/zoo.cfg

# 修改Zookeeper数据目录
RUN sed -i "s|dataDir=/tmp/zookeeper|dataDir=$ZOOKEEPER_DATA_DIR|" /opt/zookeeper/conf/zoo.cfg

# 建立Zookeeper数据目录
RUN mkdir -p $ZOOKEEPER_DATA_DIR

# 调整.ssh目录下文件权限
RUN chmod 600 $USR_SSH_CONF_DIR/config \
    && chmod 700 $USR_SSH_CONF_DIR

# 拷贝启动脚本
COPY scripts/* /opt/somebottle/haspark

# 建立HDFS目录以及工具脚本目录
RUN mkdir -p /root/hdfs/name \ 
    && mkdir -p /root/hdfs/data \
    && mkdir -p /root/hdfs/journal \
    && mkdir -p /opt/somebottle/haspark/tools

# 增加执行权限
RUN chmod +x /opt/somebottle/haspark/*.sh \
    && chmod +x $HADOOP_HOME/sbin/*.sh \
    && chmod +x $ZOOKEEPER_HOME/bin/*.sh

# 拷贝工具脚本
COPY tools/* /opt/somebottle/haspark/tools/
# 给所有工具脚本加上可执行权限
RUN chmod +x /opt/somebottle/haspark/tools/*

# 替换JSch库
COPY lib/jsch-0.2.16.jar /opt/hadoop/share/hadoop/hdfs/lib/jsch-0.1.55.jar
COPY lib/jsch-0.2.16.jar /opt/hadoop/share/hadoop/common/lib/jsch-0.1.55.jar

# 容器启动待执行的脚本
ENTRYPOINT [ "/opt/somebottle/haspark/entry.sh" ]