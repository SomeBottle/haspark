# Hadoop + Spark 分布式容器化部署

本镜像基于`bitnami/spark:3.5.0`镜像，系统为`Debian 11`，执行用户为`root`。  

面向本地集群环境测试，即**伪分布式**，应该也可以上线到真实容器集群中搭建成分布式（尚未测试）。

* 本镜像配置完成，用docker compose上线容器后，能**自动交换SSH公钥实现节点间SSH免密登录**。
* 本镜像在**WSL**上测试完成。
* [Docker hub](https://hub.docker.com/r/somebottle/haspark)  

## 版本

* Hadoop `3.3.6`
* Spark `3.5.0`  

## 默认节点分配

1 master + 2 workers.  

> 如果需要修改则需要[编辑多个文件](#修改节点数)进行重新构建。

## 可配置的环境变量  

在`bitnami/spark`的基础上添加如下环境变量: 

### Hadoop普通分布式

| 名称 | 说明 | 默认值 |
| --- | --- | --- |
| `HADOOP_MASTER` | HDFS NameNode所在主节点主机名 | 无 |
| `HADOOP_WORKERS` | **空格分隔**的HDFS从节点主机名列表 | 无 |
| `DN_ON_MASTER` | 在HDFS NameNode所在节点上是否启动DataNode | `"false"` |
| `SECONDARY_DN_NODE` | Secondary Namenode所在结点的主机名，留空则不启动 | 无 |
| `HDFS_REPLICATION` | HDFS副本数 | `2` |
| `YARN_RM_NODE` | Yarn ResourceManager所在节点 | 无 |
| `NM_WITH_RM` | 在ResourceManager所在节点是否启动NodeManager | `"false"` |
| `NM_WITH_RM` | 在ResourceManager所在节点是否启动NodeManager | `"false"` |
| `HDFS_LAUNCH_ON_STARTUP` | 是否在容器启动时自动启动HDFS各个节点的守护进程 | `"false"` |  
| `YARN_LAUNCH_ON_STARTUP` | 是否在容器启动时自动启动Yarn各个节点的守护进程 | `"false"` |  

### Hadoop高可用（HA）分布式

| 名称 | 说明 | 默认值 |
| --- | --- | --- |
|`HA_HDFS_NAMESERVICE`|HDFS高可用集群的服务名（逻辑地址）| `"hacluster"` |
|`NAMENODE_NODES`|需要启动NameNode的节点的主机名列表（空格分隔）| 空 |
|`JOURNALNODE_NODES`|需要启动JournalNode的节点的主机名列表（空格分隔）| 空 |

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
|`SH_HOSTS` | 集群中所有节点的主机名 |



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

以下是本镜像创建的容器内部常用端口，你可以选择性地在`docker-compose.yml`中将一些端口映射出来。

> 注：本镜像采用的是Hadoop集群默认端口。

| 端口 | 服务 |
| --- | --- |
| `9870` | Namenode WebUI（http） |
| `8088` | Yarn ResourceManager WebUI（http） |
| `8042` | Yarn NodeManager WebUI（http） |
| `8020` | `fs.defaultFS`绑定到的端口；Namenode的RPC端口 |
| `8485` | JournalNode的RPC端口 |

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

## 感谢

* [使用 Docker 快速部署 Spark + Hadoop 大数据集群 - s1mple的文章 - 知乎](https://zhuanlan.zhihu.com/p/421375012)  
* [Default Ports Used by Hadoop Services (HDFS, MapReduce, YARN)](https://kontext.tech/article/265/default-ports-used-by-hadoop-services-hdfs-mapreduce-yarn)  
* [官方Hadoop HA配置文档](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/HDFSHighAvailabilityWithQJM.html)  
