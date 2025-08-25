#!/bin/sh

#########可修改区#########

# 这里可以自己添加、修改 CloudflareST 的运行参数
cstconfig=""
# 检测国外连接参数
word="google.com"
# 检测国内连接参数
home="baidu.com"
# 检测节点是否在线
JDURL=""
# 定义目标文件夹
target_dir="/etc/ip"
# 定义文件路径
nowip_file="nowip_hosts.txt"
#定时修改
task="*/10 * * * *"
# 节点关键字
KEYWORD=""

#########可修改区########

# 初始化设置
NULL="/dev/null"
passwall_file="/etc/config/passwall"
START="/etc/init.d/passwall start"
STOP="/etc/init.d/passwall stop"
script_name=$(basename "$0")
script_path=$(cd "$(dirname "$0")" && pwd)/"$script_name"
new_task="$task sh $target_dir/$script_name --auto"

# 检查依赖并自动安装
for cmd in curl ping awk sed pgrep; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "缺少依赖: $cmd，尝试安装..."
        pkg=$cmd
        case $cmd in
            ping)   pkg="iputils-ping" ;;      # 或 busybox 提供
            awk)    pkg="gawk" ;;              # busybox awk 功能有限
            pgrep)  pkg="procps-ng-pgrep" ;;   # OpenWrt 提供 pgrep 的包
        esac
        opkg update
        opkg install $pkg || { echo "依赖 $cmd 安装失败，请手动安装"; exit 1; }
    fi
done

# 自动复制自身
self_copy() {
    [ -d "$target_dir" ] || mkdir -p "$target_dir"

    for dest in "$target_dir/$script_name" "/usr/bin/cfst"; do
        if [ ! -f "$dest" ] || ! cmp -s "$script_path" "$dest"; then
            cp -f "$script_path" "$dest" && chmod +x "$dest"
            echo "已复制脚本到 $dest"
        fi
    done
}
self_copy

# 添加定时任务（仅第一次）
crontab -l 2>$NULL | grep -Fxq "$new_task" || {
    (crontab -l 2>$NULL || true; echo "$new_task") | crontab -
    echo "已添加定时任务：$new_task"
}

cd "$target_dir" || exit 1

# 检查 passwall 状态
check_passwall_status() {
    if ! pgrep -f "passwall" >$NULL || { [ -f "$passwall_file" ] && grep -q "option enabled '0'" "$passwall_file"; }; then
        echo "Passwall 未运行或未启用，退出脚本"
        exit 1
    fi
}
check_passwall_status

# 国内/节点检测
check_network() {
    local ping_home=$(ping -c 3 -i 1 -W 2 $home 2>$NULL | grep -c 'bytes from')
    [ "$ping_home" -lt 2 ] && { echo "国内网络异常，退出"; exit 0; }
    echo "国内网络正常"

    local fail=0
    for i in $(seq 1 3); do
        if ! curl -s -m 5 -o $NULL -w "%{http_code}" "$JDURL" | grep -qE '^(200|301)$'; then
            fail=$((fail+1))
            [ $fail -ge 2 ] && { echo "节点离线，退出"; exit 1; }
        fi
        sleep 1
    done
    echo "节点在线"
}
check_network

# 国外检测
check_foreign() {
    for i in $(seq 1 3); do
        if curl -s -m 5 -o $NULL -w "%{http_code}" "$word" | grep -qE '^(200|301)$'; then
            echo "国外网络正常，退出"
            exit 0
        fi
        sleep 1
    done
    echo "国外网络异常，开始优选 IP"
}

# 下载 CloudflareST
download_cfst() {
    OS=$(uname -s)
    ARCH=$(uname -m)
    BASE_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/latest/download"

    case "$OS" in
        Linux)
            [ "$ARCH" = "x86_64" ] && FILE_NAME="CloudflareST_linux_amd64.tar.gz"
            [ "$ARCH" = "aarch64" ] && FILE_NAME="CloudflareST_linux_arm64.tar.gz"
            ;;
        Darwin)
            [ "$ARCH" = "x86_64" ] && FILE_NAME="CloudflareST_darwin_amd64.tar.gz"
            [ "$ARCH" = "arm64" ] && FILE_NAME="CloudflareST_darwin_arm64.tar.gz"
            ;;
        *) echo "不支持的操作系统: $OS"; exit 1 ;;
    esac

    [ -z "$FILE_NAME" ] && { echo "不支持的架构: $ARCH"; exit 1; }

    echo "正在下载 CloudflareST..."
    if ! curl -sSL -o "${FILE_NAME}" "${BASE_URL}/${FILE_NAME}" || ! tar -xzf "${FILE_NAME}"; then
        echo "下载或解压失败"
        exit 1
    fi
    rm -f "${FILE_NAME}" "cfst_hosts.sh" "使用+错误+反馈说明.txt"
}
[ -f "CloudflareST" ] || download_cfst

# IP 替换函数（去掉自动备份）
replace_ip() {
    local keyword=$1 bestip=$2
    sed -i "/option remarks '$keyword'/,/option address/ {
        /option address/ s/'.*'/'$bestip'/ }" "$passwall_file"
}

# IP 选择流程
process_ip_selection() {
    [ -f "$nowip_file" ] || touch "$nowip_file"
    NOWIP=$(head -1 "$nowip_file")

    $STOP
    ./CloudflareST $cstconfig

    BESTIP=$(awk -F, 'NR==2{print $1; exit}' result.csv 2>$NULL)
    [ -z "$BESTIP" ] && { echo "未获取到 IP，恢复运行"; $START; exit 0; }

    # IP 格式校验
    if ! echo "$BESTIP" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$|:'; then
        echo "无效 IP: $BESTIP"
        $START
        exit 1
    fi

    echo "$BESTIP" > "$nowip_file"
    echo "旧 IP: ${NOWIP:-无} → 新 IP: ${BESTIP}"

    replace_ip "$KEYWORD" "$BESTIP"
    rm -f result.csv
    $START
    echo "替换完成，Passwall 已重启"
}

# 手动/自动模式
manual_select() {
    if [ "$1" = "--auto" ]; then
        check_foreign
        grep -q "$KEYWORD" $passwall_file || { echo "未找到节点 $KEYWORD"; exit 1; }
        process_ip_selection
    else
        echo "手动优选：5 秒内按任意键触发"
        if read -t 5 -n 1; then
            grep -q "$KEYWORD" $passwall_file || { echo "未找到节点 $KEYWORD"; exit 1; }
            process_ip_selection
        else
            check_foreign
            grep -q "$KEYWORD" $passwall_file || { echo "未找到节点 $KEYWORD"; exit 1; }
            process_ip_selection
        fi
    fi
}

manual_select "$1"
exit 0
