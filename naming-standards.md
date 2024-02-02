# 命名标准

为了方便维护这个镜像，对命名标准作一些简单的规定。  

## yml配置文件中的占位符名

占位符形如`%%占位符名%%`。

### HDFS

无论高可用还是普通分布式配置，以`HDFS_`开头。

* 主要是`hdfs-site.xml`和`core-site.xml`配置

### YARN

无论高可用还是普通分布式配置，以`YARN_`开头。

* 主要是`yarn-site.xml`和`mapred-site.xml`配置

### ZooKeeper

无论高可用还是普通分布式配置，以`ZK_`开头。

### 可重复配置

配置文件中有些可重复配置，由`@#HA_REPEAT_标识名_START#@`和`@#HA_REPEAT_标识名_END#@`包裹起来。  

在这部分内容中，和重复相关的占位符名以**标识名_**为前缀。

* 比如`@#HA_REPEAT_NAMENODE_START#@`和`@#HA_REPEAT_NAMENODE_END#@`包裹起来的可重复配置中，NAMENODE名占位符为`NAMENODE_NAME`。
* 当然与重复无关的占位符命名依旧按上面HDFS和YARN等规则进行。

## 环境变量配置中的变量名

目前主要是`conf.env`。  

### 前缀

* 通用配置: 以`HADOOP_`为前缀。
* 高可用：以`HA_`为前缀。  
* 普通分布式：以`GN_`为前缀。

### 前缀之后

要能体现出配置对应的组件。  

* 比如高可用配置中`NAMENODE`的配置以`HA_NAMENODE_`开头
* 比如普通分布式配置中的`DATANODE`配置以`GN_DATANODE_`开头