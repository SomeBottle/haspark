# Hadoop + Spark 容器化部署镜像

本镜像基于`bitnami/spark:3.5.0`镜像，系统为`Debian 11`，执行用户为`root`。 

* [Github: somebottle/haspark](https://github.com/SomeBottle/haspark)  

* [DockerHub: somebottle/haspark](https://hub.docker.com/r/somebottle/haspark)  

```bash
docker pull somebottle/haspark
```

面向本地集群环境测试，即**伪分布式**，应该也可以上线到真实容器集群中搭建成分布式（尚未测试）。  

设计理念是**简单配置，快速上线测试**，因此配置项较少。  

如果有增加配置项的需要，欢迎发[Issue](https://github.com/SomeBottle/haspark/issues)亦或者开[Pull request](https://github.com/SomeBottle/haspark/pulls)！  

## 1. 关于本镜像

* 支持 **Hadoop HA（高可用）集群** 的简单部署。
* 本镜像配置完成，用 `docker compose` 部署上线容器后，能**自动交换 SSH 公钥实现节点间 SSH 免密登录**。
* 依赖于SSH的多节点进程启动同步机制：本镜像在进行多个容器上Hadoop组件部署的时候，可能会等待各节点相应进程全启动完毕再进入下一步。  
  在启动**高可用集群**的时候可能需要等待较长的一段时间。  
* 本镜像在 **WSL**(Ubuntu22.04LTS) 上测试完成。  

## 2. 软件版本

* Hadoop `3.3.6`
* Spark `3.5.0`  
* Zookeeper `3.9.1`

## 3. 可配置的环境变量  

环境变量可以[写成一个文件](#62-编写docker-compose配置)，和 `docker-compose.yml` 配合使用。

在 `bitnami/spark` 镜像的基础上，本镜像新增如下环境变量: 

### 3.1. 首要配置

| 名称 | 说明 | 默认值 |
| --- | --- | --- |
|`SH_HOSTS` | 集群中所有节点的主机名（**必填**），空格分隔 |

### 3.2. Hadoop通用配置

| 名称 | 说明 | 默认值 |
| --- | --- | --- |
| `HADOOP_LAUNCH_MODE` | Hadoop部署模式 - `general`(普通分布式)或`ha`(高可用分布式) | `"general"` |
| `HADOOP_HDFS_REPLICATION` | HDFS副本数 | `2` |
| `HADOOP_MAP_MEMORY_MB` | 为每个Map任务分配的内存量 (以**MiB**为单位) | `1024` |
| `HADOOP_REDUCE_MEMORY_MB` | 为每个Reduce任务分配的内存量 (以**MiB**为单位) | `1024` |


### 3.3. Hadoop普通分布式

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

### 3.4. Hadoop高可用（HA）分布式

| 名称 | 说明 | 默认值 |
| --- | --- | --- |
|`HA_HDFS_NAMESERVICE`|HDFS高可用集群的服务名（逻辑地址）| `"hacluster"` |
|`HA_HDFS_SETUP_ON_STARTUP`| 是否部署高可用 HDFS 集群 | `"false"` |  
|`HA_NAMENODE_HOSTS`|需要启动NameNode的节点的主机名列表（空格分隔）| 空 |
|`HA_JOURNALNODE_HOSTS`|需要启动JournalNode的节点的主机名列表（空格分隔）| 空 |
|`HA_DATANODE_HOSTS`|需要启动DataNode的节点的主机名列表（空格分隔）| 空 |
|`HA_YARN_SETUP_ON_STARTUP`| 是否部署高可用 Yarn 集群 | `"false"` |  
|`HA_RESOURCEMANAGER_HOSTS`|需要启动ResourceManager的节点的主机名列表（空格分隔）| 空 |
|`HA_NODEMANAGER_HOSTS`|需要启动NodeManager的节点的主机名列表（空格分隔）| 空 |

## 3.5. 只读环境变量

除了 `bitnami/spark` 提供的只读环境变量外，本镜像还提供了:  

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



## 4. 提供的脚本

### 4.1. 查询集群各容器的Java进程

在命令行执行`jpsall`即可，脚本实际位于`/opt/somebottle/haspark/tools/jpsall`。 

### 4.2. Zookeeper集群管理脚本

命令行: `zoo <start|stop|status>`  

脚本实际位于`/opt/somebottle/haspark/tools/zoo`。

### 4.3. Hadoop集群启停脚本

命令行: 

1. 启动集群中所有节点的相应守护进程: `start-dfs.sh | stop-dfs.sh | start-yarn.sh | stop-yarn.sh | start-all.sh | stop-all.sh`  
2. 启动本机的相应守护进程: `start-dfs-local.sh | stop-dfs-local.sh | start-yarn-local.sh | stop-yarn-local.sh | start-all-local.sh | stop-all-local.sh`


脚本实际位于`/opt/somebottle/haspark/tools/`中。

### 4.4. WordCount测试脚本

本脚本用于测试Hadoop集群是否能正常工作。

命令行: `test-wordcount.sh`

脚本实际位于`/opt/somebottle/haspark/tools/test-wordcount.sh`。

### 4.5 文件同步脚本

本脚本用于将某个节点上的文件同步到其他所有节点上（根据上面配置的 `$SH_HOSTS` 环境变量）。  

命令行: `xsync <文件名列表>`  

脚本实际位于`/opt/somebottle/haspark/tools/xsync`。

## 5. 容器部署

### 5.1. 拉取

```bash
docker pull somebottle/haspark[:tag]
```

> [:tag]可选，默认为`latest`。  

### 5.2. 编写Docker Compose配置

要快速部署伪分布式集群，可以使用Docker Compose工具。



示例配置如下，1 master + 2 worker的分配。  

<details>
<summary>==> 展开查看 <==</summary>  

```yaml
version: '3'

services:
  haspark-main:
    image: somebottle/haspark:3.1.2.1
    hostname: shmain
    env_file: ./conf.env
    environment:
      - SPARK_MODE=master
    volumes:
      - haspark-hdfs-shmain-name:/root/hdfs/name # namenode数据
      - haspark-hdfs-shmain-journal:/root/hdfs/journal
      - haspark-hdfs-shmain-data:/root/hdfs/data
      - ~/docker/spark/share:/opt/share # 三个容器映射到相同的共享目录
    ports:
      - '8080:8080'
      - '8088:8088'
      - '4040:4040'
      - '8042:8042'
      - '9870:9870'
      - '19888:19888'
  haspark-worker-1:
    image: somebottle/haspark:3.1.2.1
    hostname: shworker1
    env_file: ./conf.env
    environment:
      - SPARK_MODE=worker
      - SPARK_MASTER_URL=spark://shmain:7077
      - SPARK_WORKER_MEMORY=1G
      - SPARK_WORKER_CORES=1
    volumes:
      - ~/docker/spark/share:/opt/share
      - haspark-hdfs-worker1-name:/root/hdfs/name # namenode数据
      - haspark-hdfs-worker1-journal:/root/hdfs/journal
      - haspark-hdfs-worker1-data:/root/hdfs/data # datanode数据
    ports:
      - '8081:8081'
  haspark-worker-2:
    image: somebottle/haspark:3.1.2.1
    hostname: shworker2
    env_file: ./conf.env
    environment:
      - SPARK_MODE=worker
      - SPARK_MASTER_URL=spark://shmain:7077
      - SPARK_WORKER_MEMORY=1G
      - SPARK_WORKER_CORES=1
    volumes:
      - ~/docker/spark/share:/opt/share
      - haspark-hdfs-worker2-name:/root/hdfs/name # namenode数据
      - haspark-hdfs-worker2-journal:/root/hdfs/journal
      - haspark-hdfs-worker2-data:/root/hdfs/data # datanode数据
    ports:
      - '8082:8081'
      - '8089:8088'
      - '9871:9870'

volumes:
  haspark-hdfs-shmain-name:
  haspark-hdfs-shmain-data:
  haspark-hdfs-shmain-journal:
  haspark-hdfs-worker1-name:
  haspark-hdfs-worker1-data:
  haspark-hdfs-worker1-journal:
  haspark-hdfs-worker2-name:
  haspark-hdfs-worker2-data:
  haspark-hdfs-worker2-journal:
```

</details>  

**这其实就是本仓库的[`docker-compose.yml`](./docker-compose.yml)，其搭配着[`conf.env`](./conf.env)进行配置**。  

* 端口映射相关的配置可以参考[这里](#6-容器内常用端口)。

本仓库的配置使得容器**首次上线**时，会创建几个Docker卷。 

随后这些Docker卷会保持映射到HDFS的`NameNode`和`DataNode`目录（在HA集群下还有`JournalNode`的数据目录），以实现HDFS数据持久化（除非你移除了这些卷）。

> Docker Compose Volume配置文档:  
> https://docs.docker.com/storage/volumes/#use-a-volume-with-docker-compose  

### 5.3. 上线容器

在`docker-compose.yml`所在目录中执行:  

```bash
docker compose up -d # 守护模式启动
```

### 5.4. 停止和启动容器

> ⚠️ 建议你在执行这一步前先在容器内调用`stop-all.sh`脚本停止Hadoop集群。  

在`docker-compose.yml`所在目录中执行：

```bash
docker compose stop # 停止容器
docker compose start # 启动容器
```

### 5.5. 下线容器

在`docker-compose.yml`所在目录中执行。

1. 下线容器，保留HDFS数据:  

    > ⚠️ 建议你在执行这一步前先在容器内调用`stop-all.sh`脚本停止Hadoop集群。  

    ```bash
    docker compose down
    ```

2. 如果你想把HDFS的数据连带清空:  

    （这个操作会把相关的Docker卷全部移除）

    ```bash
    docker compose down -v # v代表volumes
    ```

### 5.6. 启动与停止Hadoop

你可以在集群任意一个节点上执行以下脚本。

Hadoop集群启动脚本：

```bash
start-all.sh  
```

Hadoop集群停止脚本：

```bash
stop-all.sh  
```

## 6. 容器内常用端口

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

## 7. 数据存储目录

### 7.1. HDFS

* NameNode: `/root/hdfs/name`  
* DataNode: `/root/hdfs/data`  
* JournalNode: `/root/hdfs/journal`  

> -> 建议挂载卷(Volume)到NameNode和DataNode以及JournalNode的目录上，可以保留HDFS的数据。  
> -> 尤其在**高可用**集群中，要注意根据NameNode和DataNode所在容器决定挂载规则。  
> -----> 比如在只有NameNode的节点上可以仅挂载NameNode的卷，但若同时还有DataNode，则也要挂载DataNode的卷。  

### 7.2. 日志
* Hadoop的日志位于`/opt/hadoop/logs`目录。
* 容器启动时初始化的日志位于`/opt/somebottle/haspark/logs`目录，用于调试。

## 感谢

* [使用 Docker 快速部署 Spark + Hadoop 大数据集群 - s1mple的文章 - 知乎](https://zhuanlan.zhihu.com/p/421375012)  

* [Default Ports Used by Hadoop Services (HDFS, MapReduce, YARN)](https://kontext.tech/article/265/default-ports-used-by-hadoop-services-hdfs-mapreduce-yarn)  

* [官方Hadoop HDFS HA配置文档](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/HDFSHighAvailabilityWithQJM.html)  

* [官方Hadoop ResourceManager HA配置文档](https://hadoop.apache.org/docs/stable/hadoop-yarn/hadoop-yarn-site/ResourceManagerHA.html)  

* [Hadoop 之 高可用不自动切换(ssh密钥无效 Caused by: com.jcraft.jsch.JSchException: invalid privatekey )](https://www.cnblogs.com/simple-li/p/14654812.html)  

* [Fencing Method for ZK based HA in Hadoop](https://cornerhadoop.blogspot.com/2017/01/fencing-method-for-zk-based-ha-in-hadoop.html)  
  
* [关于为什么fencing method还要加个无操作(`true`)的备选项](https://community.cloudera.com/t5/Support-Questions/What-s-purpose-of-shell-bin-true-in-HDFS-HA-fencer/m-p/152515/highlight/true#M114982)  

## License

Apache License, Version 2.0