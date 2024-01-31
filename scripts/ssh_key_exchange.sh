#!/bin/bash

FLAG_DIR="/root/.ssh/exchange_flags"
# 重试公钥分发次数
# 因为其他容器SSH服务还没有完全启动时，有概率会导致公钥分发失败
MAX_RETRY=7

# 临时密码文件不存在，说明已经交换过了
if [ ! -e $TEMP_PASS_FILE ]; then
    echo "SSH KEY has been exchanged before, exit."
    exit 0
fi

# 先建立RSA密钥对
ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ''

retryCnt=0
# 将公钥复制到其他容器
# 利用sshpass结合ssh-copy-id命令分发本主机公钥到其他容器
for i in $SH_HOSTS; do
    retryCnt=0
    if [ $i != "$(hostname)" ]; then
        while [ $retryCnt -lt $MAX_RETRY ]; do
            # 分发公钥
            # 然后在其他容器放置标记文件，表示已经分发过公钥
            # 注意一定要配置.ssh/config中的StrictHostKeyChecking，不然首次连接会有警告，导致sshpass找不到prompt
            sshpass -p $(cat $TEMP_PASS_FILE) ssh-copy-id -i /root/.ssh/id_rsa.pub root@$i && \
            sshpass -p $(cat $TEMP_PASS_FILE) ssh root@$i "touch $FLAG_DIR/$(hostname)" && \
            echo "Key sent: $(hostname) -> $i"
            if [ $? -eq 0 ]; then
                break
            else
                # 分发不成功则重试
                ((retryCnt++))
                echo "Failed to send key. Will retry $retry_count/$MAX_RETRY after 5 seconds..."
                sleep 5 # 重试间隔5秒
            fi
        done
        if [ $retryCnt -ge $MAX_RETRY ]; then # 分发失败
            echo "Failed to send key to $i !"
            exit 1
        fi
    fi
done

# 本机公钥也加入authorized_keys，Hadoop启动时还要和本机进行ssh连接
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
# 把本机先标记上
touch $FLAG_DIR/$(hostname)

# 等待整个分发过程收敛
while true; do
    # 每个容器与本机交换公钥后会在$FLAG_DIR目录下放置一个标记文件，文件名为其hostname
    finished=true
    for i in $SH_HOSTS; do
        if [ ! -e $FLAG_DIR/$i ]; then # 如果有的主机名还没出现，则表示还没收敛
            finished=false
            break
        fi
    done
    # 收敛
    if $finished; then
        break
    fi
    sleep 1
done

# 分发完成删除临时密码文件
rm -f $TEMP_PASS_FILE

# 完成后禁止密码登录
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
/etc/init.d/ssh restart