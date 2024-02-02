# Lib

这个目录里存放着一些用于替换的库文件，如`jar`包。  

## JSch

Hadoop HA中sshfence机制在公钥验证会出错:  

```log
2024-02-02 11:52:52,047 WARN org.apache.hadoop.ha.SshFenceByTcpPort: Unable to connect to shmain as user root
com.jcraft.jsch.JSchException: Auth fail
        at com.jcraft.jsch.Session.connect(Session.java:519)
        at org.apache.hadoop.ha.SshFenceByTcpPort.tryFence(SshFenceByTcpPort.java:99)
        at org.apache.hadoop.ha.NodeFencer.fence(NodeFencer.java:113)
        at org.apache.hadoop.ha.NodeFencer.fence(NodeFencer.java:92)
        at org.apache.hadoop.ha.ZKFailoverController.doFence(ZKFailoverController.java:559)
        at org.apache.hadoop.ha.ZKFailoverController.fenceOldActive(ZKFailoverController.java:532)
        at org.apache.hadoop.ha.ZKFailoverController.access$1100(ZKFailoverController.java:63)
        at org.apache.hadoop.ha.ZKFailoverController$ElectorCallbacks.fenceOldActive(ZKFailoverController.java:968)
        at org.apache.hadoop.ha.ActiveStandbyElector.fenceOldActive(ActiveStandbyElector.java:1022)
        at org.apache.hadoop.ha.ActiveStandbyElector.becomeActive(ActiveStandbyElector.java:921)
        at org.apache.hadoop.ha.ActiveStandbyElector.processResult(ActiveStandbyElector.java:499)
        at org.apache.zookeeper.ClientCnxn$EventThread.processEvent(ClientCnxn.java:684)
        at org.apache.zookeeper.ClientCnxn$EventThread.run(ClientCnxn.java:563)
```

* 原因: JSch不支持新的密钥签名方法。  
* 相关帖子: https://stackoverflow.com/questions/72743823/public-key-authentication-fails-with-jsch-but-work-with-openssh-with-the-same-ke 
* 解决: 替换`jsch-0.1.55.jar`为较新的`jsch-0.2.16.jar`。