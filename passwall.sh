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
sh="sh"
temp_config=$(mktemp) || exit 1
trap 'rm -f "$temp_config"' EXIT
passwall_file="/etc/config/passwall"
START="/etc/init.d/passwall start"
STOP="/etc/init.d/passwall stop"
script_name=$(basename "$0")
script_path=$(cd "$(dirname "$0")" && pwd)/"$script_name"
new_task="$task $sh $target_dir/$script_name"

# 自动复制自身到目标目录
self_copy() {
    [ -d "$target_dir" ] || mkdir -p "$target_dir"
    if [ ! -f "$target_dir/$script_name" ] || 
       ! cmp -s "$script_path" "$target_dir/$script_name"; then
        cp -f "$script_path" "$target_dir/" && \
        chmod +x "$target_dir/$script_name" && \
        echo "已复制脚本到 $target_dir/$script_name"
    fi
    
    # 复制到/usr/bin/cfst
    if [ ! -f "/usr/bin/cfst" ] || ! cmp -s "$script_path" "/usr/bin/cfst"; then
        cp -f "$script_path" "/usr/bin/cfst" && \
        chmod +x "/usr/bin/cfst" && \
        echo "已复制脚本到 /usr/bin/cfst，之后可直接在终端输入cfst运行此脚本。不用写路径"
    fi
}


# 添加定时任务
crontab -l 2>$NULL | grep -Fxq "$new_task" || {
    echo "已添加定时任务"
    (crontab -l 2>$NULL || true; echo "$new_task") | crontab -
}

cd "$target_dir" || exit 1

# 检查passwall状态
if ! pgrep -f "passwall" >$NULL || 
   { [ -f "$passwall_file" ] && grep -q "option enabled '0'" "$passwall_file"; }; then
    echo "passwall未运行或未启用 退出脚本"
    exit 1
fi

# 网络检测函数
check_network() {
    # 国内网络检测
    local ping_home=$(ping -c 3 -i 1 -W 2 $home 2>$NULL | grep -c 'bytes from')
    [ "$ping_home" -lt 2 ] && { echo "国内网络异常 退出"; exit 0; }
    echo "国内网络正常"

    # 节点在线检测
    local fail=0
    for i in {1..3}; do
        if ! curl -s -m 5 -o $NULL -w "%{http_code}" "$JDURL" | grep -qE '^(200|301)$'; then
            fail=$((fail+1))
            [ $fail -ge 2 ] && { echo "节点离线 退出"; exit 1; }
        fi
        sleep 1
    done
    echo "节点在线"
}

check_network

# 国外网络检测函数
check_foreign() {
    for i in {1..3}; do
        if curl -s -m 5 -o $NULL -w "%{http_code}" "$word" | grep -qE '^(200|301)$'; then
            echo "国外网络正常 退出"
            exit 0
        fi
        sleep 1
    done
    echo "国外网络异常 开始优选IP"
}

# 下载CloudflareST
download_cfst() {
    OS=$(uname -s)
    ARCH=$(uname -m)
    BASE_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/latest/download"

    case "$OS" in
        Linux)
            [ "$ARCH" == "x86_64" ] && FILE_NAME="CloudflareST_linux_amd64.tar.gz"
            [ "$ARCH" == "aarch64" ] && FILE_NAME="CloudflareST_linux_arm64.tar.gz"
            ;;
        Darwin)
            [ "$ARCH" == "x86_64" ] && FILE_NAME="CloudflareST_darwin_amd64.tar.gz"
            [ "$ARCH" == "arm64" ] && FILE_NAME="CloudflareST_darwin_arm64.tar.gz"
            ;;
        *) echo "不支持的操作系统: $OS"; exit 1 ;;
    esac

    [ -z "$FILE_NAME" ] && { echo "不支持的架构: $ARCH"; exit 1; }

    echo "正在下载CloudflareST..."
    if ! curl -sSL -o "${FILE_NAME}" "${BASE_URL}/${FILE_NAME}" || ! tar -xzf "${FILE_NAME}"; then
        echo "下载或解压失败"
        exit 1
    fi
    rm -f "${FILE_NAME}" "cfst_hosts.sh" "使用+错误+反馈说明.txt"
}

[ -f "CloudflareST" ] || download_cfst

# IP替换函数
replace_ip() {
    local keyword=$1 bestip=$2
    sed -i "/option remarks '$keyword'/,/option address/ {
        /option address/ s/'.*'/'$bestip'/
    }" "$passwall_file"
}

# 手动优选流程
manual_select() {
    echo "手动优选IP请按任意键"
    if read -t 5 -n 1; then
        grep -q "$KEYWORD" $passwall_file || { echo "未找到指定节点名称 $KEYWORD"; exit 1; }
        echo "找到指定节点 $KEYWORD，开始手动优选IP"
        process_ip_selection
    else
        check_foreign
        grep -q "$KEYWORD" $passwall_file || { echo "未找到指定节点名称 $KEYWORD"; exit 1; }
        echo "找到指定节点 $KEYWORD，开始自动优选IP"
        process_ip_selection
    fi
}

# IP选择处理流程
process_ip_selection() {
    [ -f "$nowip_file" ] || touch "$nowip_file"
    NOWIP=$(head -1 "$nowip_file")
    
    $STOP
    ./CloudflareST $cstconfig
    
    BESTIP=$(awk -F, 'NR==2{print $1; exit}' result.csv 2>$NULL)
    [ -z "$BESTIP" ] && { $START; exit 0; }
    
    echo "$BESTIP" > "$nowip_file"
    echo -e "\n旧 IP 为 ${NOWIP}\n新 IP 为 ${BESTIP}\n开始替换..."
    
    replace_ip "$KEYWORD" "$BESTIP"
    rm -f result.csv
    $START
    echo "替换完成，PassWall 已重启"
}

manual_select
exit 0