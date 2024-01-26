# 采用bitnami/spark镜像，此镜像基于精简Debian 11系统
# 基于Spark 3.5.0版本
# 适配Hadoop 3.3+
FROM bitnami/spark:3.5.0

LABEL maintainer="somebottle <somebottle@gmail.com>"
LABEL description="Docker image with Spark 3.5.0 and Hadoop 3.3.6, based on bitnami/spark image. For my graduation project." 

# 环境变量配置
# 所有节点的主机名，用于SSH配置
ENV SH_HOSTS="shmain shworker1 shworker2"
# Hadoop版本
ENV HADOOP_VER="3.3.6" 
# Hadoop安装目录
ENV HADOOP_HOME="/opt/hadoop"
# Hadoop配置目录
ENV HADOOP_CONF_DIR="/opt/hadoop/etc/hadoop"
# Hadoop日志目录
ENV HADOOP_LOG_DIR="/var/log/hadoop"
# 把Hadoop目录加入环境变量
ENV PATH="$HADOOP_HOME/sbin:$HADOOP_HOME/bin:$PATH"

# 以Root用户完成
USER root

# 先生成一个临时SSH密码，用于首次启动时交换ssh密钥
RUN echo $(openssl rand -base64 32) > /root/temp.pass
# 修改root用户的密码
RUN echo -e "$(cat /root/temp.pass)\n$(cat /root/temp.pass)" | passwd root


# 若.ssh目录不存在则建立
RUN [ -d /root/.ssh ] || mkdir -p /root/.ssh
# 建立标记目录
RUN mkdir -p /root/.ssh/exchange_flags

# 更换镜像源
COPY resources/sources.list /tmp/sources.list
RUN mv /tmp/sources.list /etc/apt/sources.list

# 更新apt-get以及openssh-server, wget, vim, sshpass
RUN apt-get update && apt-get install -y openssh-server wget vim sshpass

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
    && mv /tmp/tmp_configs/ssh_config /root/.ssh/config \
    && mv /tmp/tmp_configs/sshd_config /etc/ssh/sshd_config \
    && rm -rf /tmp/tmp_configs

# 调整.ssh目录下文件权限
RUN chmod 600 /root/.ssh/config \
    && chmod 700 /root/.ssh

# 拷贝启动脚本
COPY scripts/* /opt/

# 增加执行权限
RUN chmod +x /opt/start-hadoop.sh \
    && chmod +x /opt/stop-hadoop.sh \
    && chmod +x /opt/entry.sh \
    && chmod +x /opt/ssh_key_exchange.sh \
    && chmod +x $HADOOP_HOME/sbin/start-dfs.sh \
    && chmod +x $HADOOP_HOME/sbin/start-yarn.sh \
    && chmod +x $HADOOP_HOME/sbin/stop-dfs.sh \
    && chmod +x $HADOOP_HOME/sbin/stop-yarn.sh 

# 建立HDFS目录
RUN mkdir -p /root/hdfs/name \ 
    && mkdir -p /root/hdfs/data 

# 初始化HDFS
RUN hdfs namenode -format

# 容器启动待执行的脚本
ENTRYPOINT [ "/opt/entry.sh" ]