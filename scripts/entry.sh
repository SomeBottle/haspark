#!/bin/bash
# 容器启动时执行的脚本

# 得到集群中所有的主机名
export SH_HOSTS="$HADOOP_MASTER $HADOOP_WORKERS"
# 修正家目录，bitnami不知道怎么想的，把文件系统根目录当家目录
# 不修正的话，ssh-copy-id没法正常运作
export HOME="$(eval echo ~$(whoami))"

# 导出到/etc/profile中，以在用户登录后的新Shell中也保持有效
# 上面export的只能在当前Shell及子进程中有效
echo -e '#!/bin/bash\nexport SH_HOSTS="'$SH_HOSTS'"\nexport HOME='$HOME >/etc/profile.d/sh_basics.sh

if [ -e $INIT_FLAG_FILE ]; then
    # 仅在容器初次启动时执行
    # 修改ssh_config
    for host in $SH_HOSTS; do
        echo -e "Host $host\n  StrictHostKeyChecking no\n" >>$USR_SSH_CONF_DIR/config
    done
fi

# 启动SSH
/etc/init.d/ssh start

# 后台执行SSH KEY交换脚本，实现免密登录
nohup /opt/ssh_key_exchange.sh >exchange.log 2>&1 &

# 初始化Zookeeper
/opt/zookeeper-setup.sh >zookeeper_setup.log 2>&1

if [[ -z "$HADOOP_LAUNCH_MODE" || "$HADOOP_LAUNCH_MODE" == "general" ]]; then
    # Hadoop初始化，如果HADOOP_LAUNCH_MODE为空，默认是general模式
    /opt/hadoop-general-setup.sh >hadoop_setup.log 2>&1
elif [[ "$HADOOP_LAUNCH_MODE" == "ha" ]]; then
    # Hadoop高可用（HA）初始化
    /opt/hadoop-ha-setup.sh >hadoop_setup.log 2>&1
fi

# 删除初始化标识，标识容器已经初始化
rm -f $INIT_FLAG_FILE

# 执行bitnami的entry脚本
source /opt/bitnami/scripts/spark/entrypoint.sh /opt/bitnami/scripts/spark/run.sh
