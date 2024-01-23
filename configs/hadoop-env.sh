export JAVA_HOME=/opt/bitnami/java # 指定为bitnami镜像自带的jdk
export HADOOP_HOME=/opt/hadoop # 安装目录
export HADOOP_MAPRED_HOME=/opt/hadoop
export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
# JDK17环境下的Hadoop启动参数
export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib --add-opens java.base/java.lang=ALL-UNNAMED"

# 以root用户运行
export HDFS_NAMENODE_USER="root"
export HDFS_DATANODE_USER="root"
export HDFS_SECONDARYNAMENODE_USER="root"
export YARN_RESOURCEMANAGER_USER="root"
export YARN_NODEMANAGER_USER="root"