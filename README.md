# Hadoop + Spark 伪分布式容器化部署

本镜像基于`bitnami/spark:3.5.0`镜像，系统为`Debian 11`，执行用户为`root`。  

面向本地集群环境测试，即**伪分布式**。

* 本镜像配置完成，用docker compose上线容器后，能**自动交换SSH公钥实现节点间SSH免密登录**。
* 本镜像在**WSL**上测试完成。
* [Docker hub](https://hub.docker.com/r/somebottle/haspark)  

## 版本

* Hadoop `3.3.6`
* Spark `3.5.0`  

## 节点分配

1 master + 2 workers.  

> 如果需要修改则需要[编辑多个文件](#修改节点数)进行重新构建。

## 特殊环境变量  

在`bitnami/spark`的基础上添加如下环境变量: 

| 名称 | 说明 | 默认值 |
| --- | --- | --- |
| HADOOP_MODE | Hadoop模式，若设为`master`则会在此容器中执行启动集群的指令 | 空 |  

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
version: '3'

services:
  haspark-main:
    image: somebottle/haspark:3.0.2
    hostname: shmain
    environment:
      - SPARK_MODE=master
      - SPARK_RPC_AUTHENTICATION_ENABLED=no
      - SPARK_RPC_ENCRYPTION_ENABLED=no
      - SPARK_LOCAL_STORAGE_ENCRYPTION_ENABLED=no
      - SPARK_SSL_ENABLED=no
      - HADOOP_MODE=master # 在主容器中其启动Hadoop集群
    volumes:
      - haspark-hdfs-name-data:/root/hdfs/name:copy # 映射docker卷到主容器的/root/hdfs/name，创建卷时复制镜像中初始化过的namenode数据
      - ~/docker/spark/share:/opt/share # 三个容器映射到相同的共享目录
    ports:
      - '8080:8080'
      - '4040:4040'
      - '8088:8088'
      - '8042:8042'
      - '9870:9870'
      - '19888:19888'
  haspark-worker-1:
    image: somebottle/haspark:3.0.2
    hostname: shworker1
    environment:
      - SPARK_MODE=worker
      - SPARK_MASTER_URL=spark://shmain:7077
      - SPARK_WORKER_MEMORY=1G
      - SPARK_WORKER_CORES=1
      - SPARK_RPC_AUTHENTICATION_ENABLED=no
      - SPARK_RPC_ENCRYPTION_ENABLED=no
      - SPARK_LOCAL_STORAGE_ENCRYPTION_ENABLED=no
      - SPARK_SSL_ENABLED=no
    volumes:
      - ~/docker/spark/share:/opt/share
      - haspark-hdfs-worker1-data:/root/hdfs/data # datanode数据
    ports:
      - '8081:8081'
  haspark-worker-2:
    image: somebottle/haspark:3.0.2
    hostname: shworker2
    environment:
      - SPARK_MODE=worker
      - SPARK_MASTER_URL=spark://shmain:7077
      - SPARK_WORKER_MEMORY=1G
      - SPARK_WORKER_CORES=1
      - SPARK_RPC_AUTHENTICATION_ENABLED=no
      - SPARK_RPC_ENCRYPTION_ENABLED=no
      - SPARK_LOCAL_STORAGE_ENCRYPTION_ENABLED=no
      - SPARK_SSL_ENABLED=no
    volumes:
      - ~/docker/spark/share:/opt/share
      - haspark-hdfs-worker2-data:/root/hdfs/data # datanode数据
    ports:
      - '8082:8081'

volumes:
  haspark-hdfs-name-data:
  haspark-hdfs-worker1-data:
  haspark-hdfs-worker2-data:
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

## 重构建容器镜像

### 修改节点数

默认的节点主机名是:  

- `shmain` (master)
- `shworker1` (worker1)
- `shworker2` (worker2)

如果你要修改节点主机名或者新增工人(worker)节点：  

1. 修改`docker-compose.yml`的`hostname`, `SPARK_MASTER_URL`，目录挂载等配置。  
2. 修改`Dockerfile`头部的`SH_HOSTS`环境变量。
3. 修改`Hadoop`相关配置。主要是`core-site.xml`, `workers`文件，可能也要改动`yarn-site.xml`。
4. 修改`ssh_config`配置文件。
5. 重新构建镜像。  

    ```bash
    docker build -t somebottle/haspark[:tag] . --network host
    ```

    > `--network host` 在WSL平台上很有效，采用和宿主机相同的网络，否则可能在容器内无法联网。 

### 修改目录

如果你想以非root用户来运行容器，那么就需要进行比较大面积的改动。  

你可能需要改动的文件:  

1. `docker-compose.yml`  
2. `Dockerfile`
3. Hadoop配置: `hdfs-site.xml`  
4. 脚本`ssh_key_exchange.sh`  
5. 脚本`start-hadoop.sh`  

然后重新构建镜像即可。

## 感谢

* [使用 Docker 快速部署 Spark + Hadoop 大数据集群 - s1mple的文章 - 知乎](https://zhuanlan.zhihu.com/p/421375012)  