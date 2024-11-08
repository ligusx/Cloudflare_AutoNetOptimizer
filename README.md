用于immortalwrt优选IP脚本设置定时更换优选ip
由于 [CloudflareST](https://github.com/Lbingyi/CloudflareST)
在immortalwrt上无法使用iptables。别说什么缺少内核依赖，我把内核依赖都编译上了，软件也安装上了。还是不行

本脚本通过修改passwall配置文件达到优选ip目的

本脚本目前仅支持passwall
目前本脚本有以下功能：
1.创建指定工作目录并复制本脚本到工作目录
2.自动下载所需要的CloudflareSpeedTest
3.自动添加任务计划，默认10分钟运行一次
4.检测passwall是否启用，未启用则退出
5.检测passwall进程是否运行，未运行则退出
6.检测国内网络是否正常，不正常则退出
7.有自动优选和手动优选两种运行模式，默认自动优选
8.支持指定节点优选
89.自动结束passwall并开始优选，优选结束后启动passwall
