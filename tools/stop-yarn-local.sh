#!/bin/bash

# 启动本地的Yarn的脚本，替代hadoop sbin目录下的start-yarn
# 先让环境变量生效
source /etc/profile

# SSH密钥交换未完成，还没有实现免密登录，不能执行本脚本
if [ -e $TEMP_PASS_FILE ]; then
    echo "SSH Key exchange not completed."
    exit 1
fi

# 容器尚未初始化完毕（Hadoop没部署完成），不能执行本脚本
if [ -e $INIT_FLAG_FILE ]; then
    echo "Hadoop not initialized."
    exit 1
fi

echo "=========== YARN Daemon Stopping ============"

# 读取YARN守护进程启动顺序进行终止
while read -r line; do
    # 排除空白行
    if [ -n "$line" ]; then
        echo "Stopping $line..."
        yarn --daemon stop $line
    fi
done <$YARN_DAEMON_SEQ_FILE
