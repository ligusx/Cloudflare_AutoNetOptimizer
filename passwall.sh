#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# --------------------------------------------------------------
#	使用说明：加在openwrt上系统--计划任务里添加定时运行，如0 9 * * * bash /mnt/mmcblk2p4/CloudflareST/cfst-DNS.sh
#	*解释：9点0分运行一次。
# --------------------------------------------------------------

echo -e "开始测速..."
NOWIP=$(head -1 nowip_hosts.txt)

/etc/init.d/passwall stop

# 这里可以自己添加、修改 CloudflareST 的运行参数

./CloudflareST -url https://cfspeed1.kkiyomi.top/200mb.bin -tl 160 -tll 45 -o "result_hosts.txt"

[[ ! -e "result_hosts.txt" ]] && echo "CloudflareST 测速结果 IP 数量为 0，跳过下面步骤..." && exit 0

BESTIP=$(sed -n "2,1p" result_hosts.txt | awk -F, '{print $1}')
if [[ -z "${BESTIP}" ]]; then
	echo "CloudflareST 测速结果 IP 数量为 0，跳过下面步骤..."
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
rm -rf result_hosts.txt
/etc/init.d/passwall restart
