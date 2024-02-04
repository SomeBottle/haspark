#!/bin/bash
# 容器启动时执行的脚本

# 修正家目录，bitnami不知道怎么想的，把文件系统根目录当家目录
# 不修正的话，ssh-copy-id没法正常运作
export HOME="$(eval echo ~$(whoami))"
# 各组件的守护进程启动顺序
export HDFS_DAEMON_SEQ_FILE=/opt/somebottle/haspark/daemon_sequence/hdfs.seq
export YARN_DAEMON_SEQ_FILE=/opt/somebottle/haspark/daemon_sequence/yarn.seq

# 创建容器部署日志目录
mkdir -p /opt/somebottle/haspark/logs
# 创建守护进程启动记录目录
# 这里存储的是守护进程的启动顺序，用于start/stop dfs/yarn/all脚本的实现。
mkdir -p /opt/somebottle/haspark/daemon_sequence
echo '' >$HDFS_DAEMON_SEQ_FILE
echo '' >$YARN_DAEMON_SEQ_FILE

# 上面export的只能在当前Shell及子进程中有效
# 导出到/etc/profile中，以在用户登录后的新Shell中也保持有效
echo -e "export SH_HOSTS='$SH_HOSTS'\n\
export HOME='$HOME'\n\
export HDFS_DAEMON_SEQ_FILE='$HDFS_DAEMON_SEQ_FILE'\n\
export YARN_DAEMON_SEQ_FILE='$YARN_DAEMON_SEQ_FILE'\n\
export TEMP_PASS_FILE='$TEMP_PASS_FILE'\n\
export INIT_FLAG_FILE='$INIT_FLAG_FILE'\n" >/etc/profile.d/sh_basics.sh

# 把JAVA_HOME也输出到/etc/profile
echo "export JAVA_HOME=$JAVA_HOME" >/etc/profile.d/java.sh

if [ -e $INIT_FLAG_FILE ]; then
    # 仅在容器初次启动时执行
    # 修改ssh_config
    for host in $SH_HOSTS; do
        echo -e "Host $host\n  StrictHostKeyChecking no\n" >>$USR_SSH_CONF_DIR/config
    done
fi

# 1. 启动SSH
/etc/init.d/ssh start

# 2. 后台执行SSH KEY交换脚本，实现免密登录
nohup /opt/somebottle/haspark/ssh_key_exchange.sh >/opt/somebottle/haspark/logs/exchange.log 2>&1 &

# 3. 先初始化Zookeeper
/opt/somebottle/haspark/zookeeper-setup.sh >/opt/somebottle/haspark/logs/zookeeper_setup.log 2>&1

# 4. 再初始化Hadoop（因为初始化HA需要Zookeeper先初始化）
if [[ -z "$HADOOP_LAUNCH_MODE" || "$HADOOP_LAUNCH_MODE" == "general" ]]; then
    # Hadoop初始化，如果HADOOP_LAUNCH_MODE为空，默认是general模式
    /opt/somebottle/haspark/hadoop-general-setup.sh >/opt/somebottle/haspark/logs/hadoop_setup.log 2>&1
elif [[ "$HADOOP_LAUNCH_MODE" == "ha" ]]; then
    # Hadoop高可用（HA）初始化
    /opt/somebottle/haspark/hadoop-ha-setup.sh >/opt/somebottle/haspark/logs/hadoop_setup.log 2>&1
fi

# 5. 删除初始化标识，标识容器已经初始化
rm -f $INIT_FLAG_FILE

# 6. 执行bitnami的entry脚本
source /opt/bitnami/scripts/spark/entrypoint.sh /opt/bitnami/scripts/spark/run.sh
