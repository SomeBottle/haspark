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
    # 临时密码文件还存在就说明SSH公钥还没交换完毕，需要等待交换完毕后再启动Hadoop
    while [ -e $TEMP_PASS_FILE ]; do
        sleep 3
    done
    # 读取环境变量，启动Hadoop组件
    if [[ -z "$HDFS_LAUNCH_ON_STARTUP" || "$HDFS_LAUNCH_ON_STARTUP" != "false" ]]; then
        echo "Starting HDFS..."
        $HADOOP_HOME/sbin/start-dfs.sh
    fi
    if [[ -z "$YARN_LAUNCH_ON_STARTUP" || "$YARN_LAUNCH_ON_STARTUP" != "false" ]]; then
        echo "Starting YARN..."
        $HADOOP_HOME/sbin/start-yarn.sh
    fi
else
    echo "Hadoop will not automatically start in this container. Set HADOOP_MODE to 'master' to start."
fi

# 执行bitnami的entry脚本

source /opt/bitnami/scripts/spark/entrypoint.sh /opt/bitnami/scripts/spark/run.sh