#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# --------------------------------------------------------------
#	使用说明：加在openwrt上系统--计划任务里添加定时运行，如0 9 * * * ash /root/cf
#	*解释：9点0分运行一次。
# --------------------------------------------------------------

# 自动检测google是否连通，不连通则开始优选ip
for i in {1..4}; do
    status=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 https://www.google.com)
    if [ $status -eq 200 ]; then
        echo "HTTP 状态码为 200，退出"
        break
    else
    
echo -e "开始测速..."

# cd到脚本所在位置
cd `dirname $0`

# 检测是否有特定文件
NOWIP=$(head -1 nowip_hosts.txt)

# 停止passwall
/etc/init.d/passwall stop

# 这里可以自己添加、修改 CloudflareST 的运行参数
./CloudflareST -n 1000 -url https://st.1275905.xyz/ -tl 240 -tll 45 -o "result_hosts.txt"

# 检测测速结果文件，没有数据会重启passwall并退出脚本
[[ ! -e "result_hosts.txt" ]]

BESTIP=$(sed -n "2,1p" result_hosts.txt | awk -F, '{print $1}')
if [[ -z "${BESTIP}" ]]; then
	echo "CloudflareST 测速结果 IP 数量为 0，跳过下面步骤..."
	/etc/init.d/passwall start
	exit 0
fi

echo ${BESTIP} > nowip_hosts.txt
echo -e "\n旧 IP 为 ${NOWIP}\n新 IP 为 ${BESTIP}\n"

echo -e "开始替换..."

# 定义文件路径
nowip_file="nowip_hosts.txt"
passwall_file="/etc/config/passwall"

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
sed -i "s/option address '.*'/option address '$line'/" "$passwall_file"
done < "$nowip_file"

echo "替换完成"

# 删除测速结果文件并启动passwall
rm -rf result_hosts.txt
/etc/init.d/passwall start
    fi
done
