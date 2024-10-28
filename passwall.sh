#!/bin/sh

#########可修改区开始#########

# 这里可以自己添加、修改 CloudflareST 的运行参数
cstconfig=""
# 检测国外连接参数
word="google.com"
# 检测国内连接参数
home="baidu.com"
# 检测节点是否在线
JDURL="你的节点域名或ip"
# 定义目标文件夹
target_dir="/etc/ip"
# 定义文件路径
nowip_file="nowip_hosts.txt"
#定时修改
task="*/5 * * * *"

##########可修改区结束########

#定义解释命令
sh="sh"

#丢弃数据定义
NULL="/dev/null"

# 定义passwall配置文件
passwall_file="/etc/config/passwall"

# passwall启动/停止命令定义
START="/etc/init.d/passwall start"
STOP="/etc/init.d/passwall stop"

# 使用basename命令获取不带路径的脚本文件名
script_name=$(basename "$0")

# 设定要添加的crontab任务
new_task="$task $sh $target_dir/$script_name"

# 检查目标文件夹是否存在
if [ ! -d "$target_dir" ]; then

# 如果不存在，创建文件夹
mkdir -p "$target_dir"
fi

# 检查文件夹是否为空
if [ -z "$(ls -A "$target_dir")" ]; then

# 如果为空，复制自身到目标文件夹
cp "$0" "$target_dir"
echo "已复制"
else

# 文件夹赋权
chmod -R +x "$target_dir"
fi

# 检查新任务是否已经存在于crontab中
if ! crontab -l | grep -Fxq "$new_task"; then

# 如果不存在，则添加新任务到crontab
echo "已添加定时任务"
(crontab -l 2>$NULL || true) | { cat; echo "$new_task"; } | crontab -
fi

# cd到指定目录
cd $target_dir

# 检查当前目录是否已经有CloudflareST文件
if [ -f "CloudflareST" ]; then
 : 
else

# 获取系统的操作系统和架构信息
OS=$(uname -s)
ARCH=$(uname -m)

# 设置下载链接前缀和后缀
BASE_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/latest/download"
FILE_PREFIX="CloudflareST"
FILE_SUFFIX=".tar.gz"

# 根据操作系统和架构设置文件名
case "$OS" in
Linux)
if [ "$ARCH" == "x86_64" ]; then
FILE_NAME="${FILE_PREFIX}_linux_amd64${FILE_SUFFIX}"
elif [ "$ARCH" == "aarch64" ]; then
FILE_NAME="${FILE_PREFIX}_linux_arm64${FILE_SUFFIX}"
else
echo "不支持的架构: $ARCH"
exit 1
fi
;;
Darwin)
if [ "$ARCH" == "x86_64" ]; then
FILE_NAME="${FILE_PREFIX}_darwin_amd64${FILE_SUFFIX}"
elif [ "$ARCH" == "arm64" ]; then
FILE_NAME="${FILE_PREFIX}_darwin_arm64${FILE_SUFFIX}"
else
echo "不支持的架构: $ARCH"
exit 1
fi
;;
*)
echo "不支持的操作系统: $OS"
exit 1
;;
esac

# 生成完整的下载链接
DOWNLOAD_URL="${BASE_URL}/${FILE_NAME}"

# 下载文件
echo "正在下载CloudflareST..."
curl -sS -L -o "${FILE_NAME}" "${DOWNLOAD_URL}" 2> $NULL
    
# 检查下载是否成功
if [ $? -ne 0 ]; then
echo "下载失败 请检查网络连接或下载链接。"
exit 1
fi
    
# 检查是否已经安装了 tar
if command -v tar > $NULL 2>&1; then
echo "tar 已经安装"
else
echo "tar 未安装 正在安装..."
opkg update
opkg install tar
fi

# 解压文件
echo "正在解压 ${FILE_NAME} ..."
tar -xzf "${FILE_NAME}"

# 删除压缩包
rm "${FILE_NAME}"
    
# 检查并删除不需要的文件
if [ -f "cfst_hosts.sh" ]; then
rm -f "cfst_hosts.sh"
fi
if [ -f "使用+错误+反馈说明.txt" ]; then
rm -f "使用+错误+反馈说明.txt"
fi
echo "下载并解压完成"
fi

# 检查PassWall配置文件中是否启用了PassWall
if [ -f $passwall_file ] && grep -q "option enabled '0'" $passwall_file; then
# 如果passwall未启用 则退出
echo "passwall未启用 退出脚本"
exit 1
fi

# 使用ps命令检查passwall进程是否存在
if ! ps | grep -v grep | grep -q "passwall"; then
echo "passwall服务未运行 退出脚本"
exit 1
fi

# 尝试ping baidu.com 6次，并计算成功次数
ping_home=$(ping -c 6 $home 2>$NULL | grep -c 'bytes from')

# 检查成功的次数，如果失败大于等于3次，则退出
if [ "$ping_home" -lt 2 ]; then
echo "国内网络异常 退出"
exit 0
# 如果成功的次数大于等于3次，则继续运行下面的命令
elif [ "$ping_home" -ge 3 ]; then
echo "国内网络正常"
fi

# 测试次数
max_attempts=5
# 允许非200状态码的最大次数
max_failures=3
# 当前非200状态码的次数
failure_count=0

for i in $(seq 1$max_attempts); do
# 执行curl命令，获取HTTP状态码
status_code=$(curl -o /dev/null -s -w "%{http_code}" -m 1 -- "$JDURL")
    
# 检查状态码是否不是200
if [ "$status_code" != "200" ]; then
# 增加非200状态码的计数
failure_count=$((failure_count+1))
fi
# 如果非200状态码的次数超过最大允许次数，则退出
if [ $failure_count -gt $max_failures ]; then
echo "节点离线 退出"
exit 1
fi
done
echo "节点在线"

# 使用read命令读取输入，并设置超时时间为5秒
echo "手动优选IP请按任意键"
if read -t 5 -n 1; then
echo "开始手动优选IP"

# 检测是否有特定文件
if [ ! -f "$nowip_file" ]; then
touch $nowip_file
fi

NOWIP=$(head -1 $nowip_file)

# 停止passwall
$STOP

./CloudflareST $cstconfig

# 检测测速结果文件，没有数据会重启passwall并退出脚本
[[ ! -e "result.csv" ]]
BESTIP=$(sed -n "2,1p" result.csv | awk -F, '{print $1}')
if [[ -z "${BESTIP}" ]]; then
echo "CloudflareST 测速结果 IP 数量为 0，跳过下面步骤..."
$START
exit 0
fi
echo ${BESTIP} > $nowip_file
echo -e "\n旧 IP 为 ${NOWIP}\n新 IP 为 ${BESTIP}\n"
echo -e "开始替换..."

# 检查文件是否存在
if [ ! -f "$nowip_file" ]; then
echo "Error: $nowip_file 文件不存在"
exit 1
fi

if [ ! -f "$passwall_file" ]; then
echo "Error: $passwall_file 文件不存在"
exit 1
fi

# 读取nowip_hosts.txt文件中的内容并处理
while IFS= read -r line; do

# 替换/etc/config/passwall文件中的option address字段中的引号中的文本
sed=$(sed -i "s/option address '.*'/option address '$line'/" "$passwall_file")
$sed
done < "$nowip_file"
echo "替换完成"

# 删除测速结果文件并启动passwall
rm -rf result.csv
$START
exit 0
else

echo "开始自动流程"

# 自动检测google是否连通，不连通则开始优选ip

# 尝试ping google.com 6次，并计算成功次数
ping_word=$(ping -c 6 $word 2>$NULL | grep -c 'bytes from')

# 检查成功的次数，如果大于等于3次，则退出
if [ "$ping_word" -ge 3 ]; then
echo "国外网络正常 退出"
exit 0
# 如果失败的次数大于等于3次，则继续运行下面的命令
elif [ "$ping_word" -lt 2 ]; then
echo "国外网络异常 即将开始优选IP"
fi

echo  "开始测速..."

# 检测是否有特定文件
if [ ! -f "$nowip_file" ]; then
touch $nowip_file
fi

NOWIP=$(head -1 $nowip_file)

# 停止passwall
$STOP

./CloudflareST $cstconfig

# 检测测速结果文件，没有数据会重启passwall并退出脚本
[[ ! -e "result.csv" ]]
BESTIP=$(sed -n "2,1p" result.csv | awk -F, '{print $1}')
if [[ -z "${BESTIP}" ]]; then
echo "CloudflareST 测速结果 IP 数量为 0，跳过下面步骤..."
$START
exit 0
fi
echo ${BESTIP} > $nowip_file
echo -e "\n旧 IP 为 ${NOWIP}\n新 IP 为 ${BESTIP}\n"
echo -e "开始替换..."

# 检查文件是否存在
if [ ! -f "$nowip_file" ]; then
echo "Error: $nowip_file 文件不存在"
exit 1
fi

if [ ! -f "$passwall_file" ]; then
echo "Error: $passwall_file 文件不存在"
exit 1
fi

# 读取nowip_hosts.txt文件中的内容并处理
while IFS= read -r line; do

# 替换/etc/config/passwall文件中的option address字段中的引号中的文本
$sed
done < "$nowip_file"
echo "替换完成"

# 删除测速结果文件并启动passwall
rm -rf result.csv
$START
fi
done