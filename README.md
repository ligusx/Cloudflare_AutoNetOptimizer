# ImmortalWrt 优选 IP 脚本设置定时更换优选 IP

由于 [CloudflareST](https://github.com/Lbingyi/CloudflareST) 在 ImmortalWrt 上无法使用 iptables。别说什么缺少内核依赖，我把内核依赖都编译上了，软件也安装上了，还是不行。

本脚本通过修改 Passwall 配置文件来实现优选 IP 目的。

## 脚本支持

目前，本脚本仅支持 Passwall。

## 功能列表

1. 创建指定工作目录并复制本脚本到工作目录。
2. 自动下载所需要的 CloudflareSpeedTest。
3. 自动添加任务计划，默认每 10 分钟运行一次。
4. 检测 Passwall 是否启用，未启用则退出。
5. 检测 Passwall 进程是否运行，未运行则退出。
6. 检测国内网络是否正常，若不正常则退出。
7. 提供自动优选和手动优选两种运行模式，默认使用自动优选。
8. 支持指定节点优选。
9. 自动结束 Passwall 并开始优选，优选结束后重新启动 Passwall。

