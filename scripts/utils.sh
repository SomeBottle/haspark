#!/bin/bash

# 工具函数脚本

function join_by() {
    # 拼接字符串
    # param1：空格分隔的字符串列表，比如"master worker1 worker2"
    # param2：分隔符，比如","
    # param3：对于每个子字符串后面要加上的后缀字符串，比如":2888"会给worker1后面加上":2181"变成"worker1:2181"
    # 使用示例： join_by "$test_hosts" ',' ':2888'
    # 注意，请用双引号括起变量，否则命令行会处理空格导致传参错误。
    old_IFS=$IFS # 保存原本的IFS
    IFS=' ' # 按空格分隔
    local arr=($1)
    local i=0
    local str=""
    for s in "${arr[@]}"; do
        if [ $i -eq 0 ]; then
            str="$s$3"
            i=1
        else
            str="$str$2$s$3"
        fi
    done
    IFS=$old_IFS
    echo "$str"
    return 0
}

function wait_for_java_process() {
    # 阻塞，直到某个Java进程启动
    # 依赖于jps指令
    # param1: Java进程名（大小写不敏感）
    echo "Waiting for ${1} to start..."
    while true; do
        sleep 0.5
        local process=$(/opt/bitnami/java/bin/jps | grep -i ${1})
        if [ -n "$process" ]; then
            echo "${1} has been started."
            break
        fi
    done
}

function wait_for_java_process_on_specified_nodes() {
    # 阻塞，直到指定节点上的指定Java进程都启动
    # 依赖于jps指令
    # param1: Java进程名（大小写不敏感）
    # param2: 节点列表（空格分隔）
    for host in $2; do
        echo "Waiting for ${1} to start on ${host}..."
        # 在指定主机上先导入utils函数，然后等待指定Java进程启动
        ssh root@$host "source /opt/somebottle/haspark/utils.sh; wait_for_java_process $1"
        echo "${1} on ${host} has been started."
    done
}

function extract_repeat_conf() {
    # 提取配置文件中的重复配置
    # 这些配置往往由 @#HA_REPEAT_标识符_START#@ 和 @#HA_REPEAT_标识符_END#@ 包裹起来
    # param1: 标识符
    # param2: 配置文件路径
    # 使用示例： extract_repeat_conf "NAMENODE" "hdfs-site.xml"

    # 用grep太鸡肋了，正好镜像中有python，用python咯
    echo $(/opt/bitnami/python/bin/python /opt/somebottle/haspark/extract_with_pattern.py "@#HA_REPEAT_${1}_START#@" "@#HA_REPEAT_${1}_END#@" "$2")
    return $?
}

function replace_repeat_conf() {
    # 替换配置文件中的重复配置部分
    # 这些配置往往由 @#HA_REPEAT_标识符_START#@ 和 @#HA_REPEAT_标识符_END#@ 包裹起来
    # param1：标识符
    # param2：待替换的字符串
    # param3：配置文件路径
    # 使用示例： remove_repeat_conf "NAMENODE" "testconf" "hdfs-site.xml"

    /opt/bitnami/python/bin/python /opt/somebottle/haspark/replace_with_pattern.py "@#HA_REPEAT_${1}_START#@" "@#HA_REPEAT_${1}_END#@" "$2" "$3"
    return $?
}

function remove_ha_conf() {
    # 移除配置中的高可用配置
    # 这些配置往往由 @#HA_CONF_START#@ 和 @#HA_CONF_END#@ 包裹起来
    # param1：配置文件路径
    # 使用示例： remove_ha_conf "hdfs-site.xml"

    /opt/bitnami/python/bin/python /opt/somebottle/haspark/replace_with_pattern.py "@#HA_CONF_START#@" "@#HA_CONF_END#@" "" "$1"
    return $?
}
