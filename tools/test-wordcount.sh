#!/bin/bash  

# 本脚本用于快速测试Yarn集群是否能正常运作。  

echo "Hello World My World" > /tmp/hello.txt
hdfs dfs -put /tmp/hello.txt /
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar wordcount /hello.txt /out