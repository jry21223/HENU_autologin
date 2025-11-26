#!/bin/ash
# /usr/bin/school_login.sh - 校园网自动登录守护脚本

# 引入 UCI 配置函数
. /lib/functions/uci.sh

LOG_FILE="/tmp/school_login.log"

log() {
    echo "$(date) $1" >> $LOG_FILE
}

# 从 UCI 配置加载变量
uci_load autoschoollogin
uci_get_state autoschoollogin settings enabled       IS_ENABLED
uci_get_state autoschoollogin settings username     USERNAME
uci_get_state autoschoollogin settings password     PASSWORD
uci_get_state autoschoollogin settings login_host   LOGIN_HOST
uci_get_state autoschoollogin settings login_path   LOGIN_PATH
uci_get_state autoschoollogin settings campus_code  CAMPUS_CODE
uci_get_state autoschoollogin settings operator_suffix OPERATOR_SUFFIX
uci_get_state autoschoollogin settings interval     INTERVAL
uci_get_state autoschoollogin settings ping_target  PING_TARGET

# 默认值设置
: ${INTERVAL:=60}
: ${PING_TARGET:="baidu.com"}

# 函数：检测网络状态
check_network() {
    ping -c 3 -W 2 "$PING_TARGET" > /dev/null 2>&1
    return $?
}

# 函数：执行登录操作
do_login() {
    # 完整的登录 URL
    LOGIN_URL="http://${LOGIN_HOST}${LOGIN_PATH}"

    # 构造 POST 请求体 (重要: 必须匹配抓包内容)
    # operatorSuffix 需要 URL 编码，但 curl 的 --data-urlencode 更可靠，这里先用原始值
    LOGIN_DATA="campusCode=${CAMPUS_CODE}&username=${USERNAME}&password=${PASSWORD}&operatorSuffix=${OPERATOR_SUFFIX}"

    log "Attempting POST to ${LOGIN_URL}..."

    # 执行 POST 请求
    # -s: 静默模式 | -k: 允许不安全连接 (可选) | -X POST: 指定方法 | -d: 提交数据
    RESPONSE=$(/usr/bin/curl -s -X POST \
        --header "Host: ${LOGIN_HOST}" \
        --header "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
        --data "$LOGIN_DATA" \
        "$LOGIN_URL")
    
    # 检查返回结果
    if [ $? -eq 0 ]; then
        # 抓包显示成功返回 {"code":1,...}
        if echo "$RESPONSE" | grep -q '{"code":1'; then
            log "Login successful! Response: ${RESPONSE}"
            return 0
        else
            log "Login failed. Received response: ${RESPONSE}"
            return 1
        fi
    else
        log "Login failed (Curl error $?)."
        return 1
    fi
}


# 主循环
main_loop() {
    if [ "$IS_ENABLED" != "1" ]; then
        log "Script is disabled. Exiting."
        exit 0
    fi
    
    while true; do
        if check_network; then
            # 如果网络已通，等待下一个周期
            : 
        else
            # 如果网络不通，尝试登录
            log "Network check failed. Initiating login."
            do_login
        fi
        
        sleep ${INTERVAL}
    done
}

main_loop