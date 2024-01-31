#!/bin/bash
# 容器启动时执行的脚本

# 得到集群中所有的主机名
export SH_HOSTS="$HADOOP_MASTER $HADOOP_WORKERS"
# 修改ssh_config
for host in $SH_HOSTS; do
    echo "Host $host\n  StrictHostKeyChecking no\n" >> $USR_SSH_CONF_DIR/config
done

# 启动SSH
/etc/init.d/ssh start
# 后台执行SSH KEY交换脚本，实现免密登录
nohup /opt/ssh_key_exchange.sh > exchange.log 2>&1 &

# Hadoop初始化
nohup /opt/ssh_key_exchange.sh > hadoop_setup.log 2>&1 &

# 执行bitnami的entry脚本

source /opt/bitnami/scripts/spark/entrypoint.sh /opt/bitnami/scripts/spark/run.sh

# 修正家目录，bitnami不知道怎么想的，把文件系统根目录当家目录
export HOME="$(eval echo ~$(whoami))"