# Hadoop + Spark 分布式容器化部署

本镜像基于`bitnami/spark:3.5.0`镜像，系统为`Debian 11`，执行用户为`root`。  

* [Docker hub](https://hub.docker.com/r/somebottle/haspark)  

```bash
docker pull somebottle/haspark
```

面向本地集群环境测试，即**伪分布式**，应该也可以上线到真实容器集群中搭建成分布式（尚未测试）。  

设计理念是**简单配置，快速上线测试**，因此配置项较少。  

如果有增加配置项的需要，欢迎发[Issue](https://github.com/SomeBottle/haspark/issues)亦或者开[Pull request](https://github.com/SomeBottle/haspark/pulls)！  

## 关于本镜像

* 本镜像配置完成，用docker compose上线容器后，能**自动交换SSH公钥实现节点间SSH免密登录**。
* 多节点进程启动同步机制：本镜像依赖于SSH，在进行多个容器上Hadoop组件部署的时候会等待各节点相应进程全启动完毕再进入下一步。
* 本镜像在**WSL**上测试完成。

## 软件版本

* Hadoop `3.3.6`
* Spark `3.5.0`  
* Zookeeper `3.9.1`

## 默认节点分配

1 master + 2 workers.  

> 如果需要修改则需要[编辑多个文件](#修改节点数)进行重新构建。

## 可配置的环境变量  

在`bitnami/spark`的基础上添加如下环境变量: 

### 首要配置

| 名称 | 说明 | 默认值 |
| --- | --- | --- |
|`SH_HOSTS` | 集群中所有节点的主机名（**必填**），空格分隔 |

### Hadoop通用配置

| 名称 | 说明 | 默认值 |
| --- | --- | --- |
| `HADOOP_LAUNCH_MODE` | Hadoop部署模式 - `general`(普通分布式)或`ha`(高可用分布式) | `"general"` |
| `HADOOP_HDFS_REPLICATION` | HDFS副本数 | `2` |
| `HADOOP_MAP_MEMORY_MB` | 为每个Map任务分配的内存量 (以**MiB**为单位) | `1024` |
| `HADOOP_REDUCE_MEMORY_MB` | 为每个Reduce任务分配的内存量 (以**MiB**为单位) | `1024` |


### Hadoop普通分布式

| 名称 | 说明 | 默认值 |
| --- | --- | --- |
| `GN_NAMENODE_HOST` | HDFS NameNode所在主节点主机名 | 无 |
| `GN_HADOOP_WORKER_HOSTS` | **空格分隔**的HDFS从节点主机名列表 | 无 |
| `GN_DATANODE_ON_MASTER` | 在HDFS NameNode所在节点上是否启动DataNode | `"false"` |
| `GN_SECONDARY_DATANODE_HOST` | Secondary Namenode所在结点的主机名，留空则不启动 | 无 |
| `GN_RESOURCEMANAGER_HOST` | Yarn ResourceManager所在节点 | 无 |
| `GN_NODEMANAGER_WITH_RESOURCEMANAGER` | 在ResourceManager所在节点是否启动NodeManager | `"false"` |
| `GN_NODEMANAGER_WITH_RESOURCEMANAGER` | 在ResourceManager所在节点是否启动NodeManager | `"false"` |
| `GN_HDFS_SETUP_ON_STARTUP` | 是否在容器启动时自动启动HDFS各个节点的守护进程 | `"false"` |  
| `GN_YARN_SETUP_ON_STARTUP` | 是否在容器启动时自动启动Yarn各个节点的守护进程 | `"false"` |  

### Hadoop高可用（HA）分布式

| 名称 | 说明 | 默认值 |
| --- | --- | --- |
|`HA_HDFS_NAMESERVICE`|HDFS高可用集群的服务名（逻辑地址）| `"hacluster"` |
|`HA_HDFS_SETUP_ON_STARTUP`| 是否在容器启动时自动初始化并启动HDFS | `"false"` |  
|`HA_NAMENODE_HOSTS`|需要启动NameNode的节点的主机名列表（空格分隔）| 空 |
|`HA_JOURNALNODE_HOSTS`|需要启动JournalNode的节点的主机名列表（空格分隔）| 空 |
|`HA_DATANODE_HOSTS`|需要启动DataNode的节点的主机名列表（空格分隔）| 空 |
|`HA_YARN_SETUP_ON_STARTUP`| 是否在容器启动时自动初始化并启动YARN | `"false"` |  
|`HA_RESOURCEMANAGER_HOSTS`|需要启动ResourceManager的节点的主机名列表（空格分隔）| 空 |
|`HA_NODEMANAGER_HOSTS`|需要启动NodeManager的节点的主机名列表（空格分隔）| 空 |

## 只读环境变量

除了`bitnami/spark`提供的只读环境变量外，本镜像还提供了:  

| 名称 | 说明 | 
| --- | --- | 
|`ZOOKEEPER_VER` | Zookeeper版本 | 
|`ZOOKEEPER_HOME` | Zookeeper安装目录 | 
|`ZOOKEEPER_CONF_DIR` | Zookeeper配置目录 | 
|`ZOOKEEPER_DATA_DIR` | Zookeeper数据目录（`zoo.cfg`中的`dataDir`配置） | 
|`HADOOP_VER` | Hadoop版本 | 
|`HADOOP_HOME` | Hadoop安装目录 | 
|`HADOOP_CONF_DIR` | Hadoop配置文件目录 |
|`HADOOP_LOG_DIR` | Hadoop日志目录 | 
|`SPARK_CONF_DIR` | Spark配置文件目录 |



## 提供的脚本

### 1. 查询集群各容器的Java进程

在命令行执行`jpsall`即可，脚本实际位于`/opt/tools/jpsall`。 

### 2. Zookeeper集群管理脚本

命令行: `zoo <start|stop|status>`  

脚本实际位于`/opt/tools/zoo`。

## 容器部署

### 1. 拉取

```bash
docker pull somebottle/haspark[:tag]
```

### 2. 编写Docker Compose配置

**首次上线**时，会创建几个Docker卷，并且将镜像内格式化过的Namenode数据复制过来。  

随后这些Docker卷会保持映射到HDFS的`NameNode`和`DataNode`目录，实现HDFS数据持久化（除非你移除了这些卷）。

> Docker Compose Volume配置文档:  
> https://docs.docker.com/storage/volumes/#use-a-volume-with-docker-compose  

在某个新目录下建立`docker-compose.yml`。

示例配置如下，1 master + 2 worker的分配。  

<details>
<summary>展开查看</summary>  

```yaml
待更新...
```

</details>  

**当然你也可以直接用本仓库的`docker-compose.yml`配置**。

### 3. 上线容器

在`docker-compose.yml`所在目录中执行。 

```bash
docker compose up -d
```

### 4. 下线容器

在`docker-compose.yml`所在目录中执行。

下线容器，保留HDFS数据:  

```bash
docker compose down
```

如果你想把HDFS的数据连带清空:  

（这个操作会把相关的Docker卷全部移除）

```bash
docker compose down -v # v代表volumes
```

### 5. 启动与停止Hadoop

按理说容器启动后，**在完成免密登录配置后会自动执行**Hadoop集群启动脚本，如果没有的话你可以手动执行:  

```bash
/opt/start-hadoop.sh  
```

Hadoop集群停止脚本：

```bash
/opt/stop-hadoop.sh  
```

## 容器内常用端口

以下是本镜像创建的容器内部常用端口，你可以选择性地在`docker-compose.yml`中将一些端口映射到宿主机。

> 注：本镜像采用的大多是默认端口。

| 端口 | 服务 |
| --- | --- |
| `9870` | Namenode WebUI（http） |
| `8088` | Yarn ResourceManager WebUI（http） |
| `8042` | Yarn NodeManager WebUI（http） |
| `19888` | Yarn JobHistory WebUI（http） |
| `8020` | `fs.defaultFS`绑定到的端口；Namenode的RPC端口 |
| `8485` | JournalNode的RPC端口 |
| `2181` | Zookeeper对客户端开放的端口 |

更多默认端口可参考官方文档:  

* https://hadoop.apache.org/docs/r3.3.6/hadoop-project-dist/hadoop-common/core-default.xml  
* https://hadoop.apache.org/docs/r3.3.6/hadoop-project-dist/hadoop-hdfs/hdfs-default.xml
* https://hadoop.apache.org/docs/r3.3.6/hadoop-mapreduce-client/hadoop-mapreduce-client-core/mapred-default.xml
* https://hadoop.apache.org/docs/r3.3.6/hadoop-yarn/hadoop-yarn-common/yarn-default.xml

## 数据存储目录

### HDFS

* NameNode: `/root/hdfs/name`  
* DataNode: `/root/hdfs/data`  
* JournalNode: `/root/hdfs/journal`

### 日志
* Hadoop的日志位于`/opt/hadoop/logs`目录。

## 感谢

* [使用 Docker 快速部署 Spark + Hadoop 大数据集群 - s1mple的文章 - 知乎](https://zhuanlan.zhihu.com/p/421375012)  

* [Default Ports Used by Hadoop Services (HDFS, MapReduce, YARN)](https://kontext.tech/article/265/default-ports-used-by-hadoop-services-hdfs-mapreduce-yarn)  

* [官方Hadoop HDFS HA配置文档](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/HDFSHighAvailabilityWithQJM.html)  

* [官方Hadoop ResourceManager HA配置文档](https://hadoop.apache.org/docs/stable/hadoop-yarn/hadoop-yarn-site/ResourceManagerHA.html)  

* [Hadoop 之 高可用不自动切换(ssh密钥无效 Caused by: com.jcraft.jsch.JSchException: invalid privatekey )](https://www.cnblogs.com/simple-li/p/14654812.html)  

* [Fencing Method for ZK based HA in Hadoop](https://cornerhadoop.blogspot.com/2017/01/fencing-method-for-zk-based-ha-in-hadoop.html)  
  
* [关于为什么fencing method还要加个无操作(`true`)的备选项](https://community.cloudera.com/t5/Support-Questions/What-s-purpose-of-shell-bin-true-in-HDFS-HA-fencer/m-p/152515/highlight/true#M114982)  