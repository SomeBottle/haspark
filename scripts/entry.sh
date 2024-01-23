#!/bin/bash
# 容器启动时执行的脚本

# 修正家目录，bitnami不知道怎么想的，把文件系统根目录当家目录
export HOME="$(eval echo ~$(whoami))"

# 启动SSH
/etc/init.d/ssh start
# 后台执行SSH KEY交换脚本，实现免密登录
nohup /opt/ssh_key_exchange.sh > exchange.log 2>&1 &

# 如果 HADOOP_MODE 为 master，则启动 Hadoop 集群
if [ "$HADOOP_MODE" = "master" ]; then
    # 在主容器下启动 Hadoop
    nohup /opt/start-hadoop.sh > hadoop_launch.log 2>&1 &
else
    echo "Hadoop will not automatically start in this container. Set HADOOP_MODE to 'master' to start."
fi

# 执行bitnami的entry脚本

source /opt/bitnami/scripts/spark/entrypoint.sh /opt/bitnami/scripts/spark/run.sh