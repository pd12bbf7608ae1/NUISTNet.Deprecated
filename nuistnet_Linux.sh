#!/bin/bash

# Modify for linux

#######################
# 南信大校园网络自动脚本
# 脚本依赖于bash环境以及curl工具。
# 使用前需要修改脚本开头的相关参数。
# 用法：
# nuistnet.sh             检测网络并尝试登陆
# nuistnet.sh login       强制执行登陆
# nuistnet.sh logout      强制注销
# nuistnet.sh status      显示登陆信息
# nuistnet.sh help        显示帮助
#
# 脚本可能由于用户环境不同而无法使用，本人不保证脚本的可用性以及对使用该脚本造成的任何后果负责。
#######################

username='123456789'
password='000000'
isp='CMCC'
# 移动 CMCC 联通Unicom 电信 ChinaNet 南信大 NUIST

password=$(echo -n "$password" | base64 -w 0)

loginServer='a.nuist.edu.cn'
loginUrl="http://${loginServer}/index.php/index/login"
logoutUrl="http://${loginServer}/index.php/index/logout"
statusUrl="http://${loginServer}/index.php/index/init"

userAgent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.105 Safari/537.36"

show_help() {
    printf "南信大校园网络自动脚本\n脚本依赖于bash环境以及curl工具。\n使用前需要修改脚本开头的相关参数。\n用法：\nnuistnet.sh\t\t检测网络并尝试登陆\nnuistnet.sh login\t强制执行登陆\nnuistnet.sh logout\t强制注销\nnuistnet.sh status\t显示登陆信息\nnuistnet.sh help\t显示帮助\n\n脚本可能由于用户环境不同而无法使用，本人不保证脚本的可用性以及对使用该脚本造成的任何后果负责。\n"
    return 0
}

check_alidns() {
    ping -c 2 223.5.5.5 > /dev/null 2>/dev/null
    return $?
}

check_loginServer() {
    ping -c 2 "${loginServer}" > /dev/null 2>/dev/null
    return $?
}

check_loginStatus() {  # 返回2 无法获取信息（网络中断） 1 已经登陆 0 未登录
    result=$(curl -H "User-Agent:${userAgent}" -X GET "${statusUrl}" 2> /dev/null)
    if [[ "$?" -ne "0" ]]; then
        status=2
        return 2
    fi
    result=$(echo "$result" | sed "s/[{}]//g" | sed "s/,/\n/g")
    status=$(echo "$result" | grep "\"status\":" | cut -d ":" -f 2)
    info=$(echo "$result" | grep "\"info\":" | cut -d ":" -f 2 | sed -e "s/\"//g")
    if [[ "$status" -eq "0" ]]; then
        return 0 # 未登录
    else
        logoutUsername=$(echo "$result" | grep "\"logout_username\":" | cut -d ":" -f 2 | sed -e "s/\"//g")
        logoutDomain=$(echo "$result" | grep "\"logout_domain\":" | cut -d ":" -f 2 | sed -e "s/\"//g")
        logoutIp=$(echo "$result" | grep "\"logout_ip\":" | cut -d ":" -f 2 | sed -e "s/\"//g")
        logoutLocation=$(echo "$result" | grep "\"logout_location\":" | cut -d ":" -f 2 | sed -e "s/\"//g")
        logoutTimer=$(echo "$result" | grep "\"logout_timer\":" | cut -d ":" -f 2 | sed -e "s/\"//g")
        return 1 #已经登陆
    fi
}

logout() {  # 返回2 无法获取信息（网络中断） 1 成功 0 失败
    result=$(curl -H "User-Agent:${userAgent}" -X POST "${logoutUrl}" 2> /dev/null)
    if [[ "$?" -ne "0" ]]; then
        status=2
        return 2
    fi
    result=$(echo "$result" | sed "s/[{}]//g" | sed "s/,/\n/g")
    status=$(echo "$result" | grep "\"status\":" | cut -d ":" -f 2)
    info=$(echo "$result" | grep "\"info\":" | cut -d ":" -f 2 | sed -e "s/\"//g")
    if [[ "$status" -eq "0" ]]; then
        return 0
    else
        return 1
    fi
}

login() {  # 返回2 无法获取信息（网络中断） 1 成功 0 失败
    result=$(curl -H "User-Agent:${userAgent}" -X POST -d "username=${username}&domain=${isp}&password=${password}&enablemacauth=0" "${loginUrl}" 2> /dev/null)
    if [[ "$?" -ne "0" ]]; then
        status=2
        return 2
    fi
    result=$(echo "$result" | sed "s/[{}]//g" | sed "s/,/\n/g")
    status=$(echo "$result" | grep "\"status\":" | cut -d ":" -f 2)
    info=$(echo "$result" | grep "\"info\":" | cut -d ":" -f 2 | sed -e "s/\"//g")
    if [[ "$status" -eq "0" ]]; then
        return 0
    else
        logoutUsername=$(echo "$result" | grep "\"logout_username\":" | cut -d ":" -f 2 | sed -e "s/\"//g")
        logoutDomain=$(echo "$result" | grep "\"logout_domain\":" | cut -d ":" -f 2 | sed -e "s/\"//g")
        logoutIp=$(echo "$result" | grep "\"logout_ip\":" | cut -d ":" -f 2 | sed -e "s/\"//g")
        logoutLocation=$(echo "$result" | grep "\"logout_location\":" | cut -d ":" -f 2 | sed -e "s/\"//g")
        return 1
    fi
}

check_and_login() {

    echo "测试网络通断..."
    check_alidns
    if [[ "$?" -eq "0" ]]; then
        echo "已经联网，退出。"
        exit 0
    fi

    echo "网络断开，尝试连接登录服务器..."
    check_loginServer
    if [[ "$?" -ne "0" ]]; then
        echo "登录服务器无法连接，退出。"
        exit 0
    fi

    check_loginStatus
    if [[ "$?" -ne "0" ]]; then
        case "${status}" in
            "2")
                echo "登录服务器可能宕机，请稍后再试。"
                ;;
            "1")
                echo "登录服务器显示已经登录，网络可能不稳定。"
                echo "登录信息："
                printf "账户：\t${logoutUsername}\nISP：\t${logoutDomain}\nIP：\t${logoutIp}\n地点：\t${logoutLocation}\n时长：\t${logoutTimer}s\n"
                echo "放弃登录。"
                ;;
        esac
        exit 0
    fi

    echo "进行登录..."
    login
    if [[ "$?" -ne "1" ]]; then
        case "${status}" in
            "2")
                echo "登录服务器可能宕机，请稍后再试。"
                ;;
            "0")
                echo "登录失败。"
                printf "信息：\t${info}\n"
                if [[ "$info" == "Limit Users Err" ]]; then
                    printf "翻译：\t用户数目达到上限，请登出其他设备。\n"
                fi

                if [[ "$info" == "UserName_Err" ]]; then
                    printf "翻译：\t用户名错误。\n"
                fi

                if [[ "$info" == "Passwd_Err" ]]; then
                    printf "翻译：\t密码错误。\n"
                fi
                ;;
        esac
        exit 0
    fi

    echo "登录成功！"
    printf "账户：\t${logoutUsername}\nISP：\t${logoutDomain}\nIP：\t${logoutIp}\n地点：\t${logoutLocation}\n"
    return 0
}

force_login() {
    echo "强制登录..."
    login
    if [[ "$?" -ne "1" ]]; then
        case "${status}" in
            "2")
                echo "登录服务器可能宕机，请稍后再试。"
                ;;
            "0")
                echo "登录失败。"
                printf "信息：\t${info}\n"
                if [[ "$info" == "Limit Users Err" ]]; then
                    printf "翻译：\t用户数目达到上限，请登出其他设备。\n"
                fi

                if [[ "$info" == "UserName_Err" ]]; then
                    printf "翻译：\t用户名错误。\n"
                fi

                if [[ "$info" == "Passwd_Err" ]]; then
                    printf "翻译：\t密码错误。\n"
                fi
                ;;
        esac
        exit 0
    fi

    echo "登录成功！"
    printf "账户：\t${logoutUsername}\nISP：\t${logoutDomain}\nIP：\t${logoutIp}\n地点：\t${logoutLocation}\n"
    return 0
}

force_logout() {
    echo "退出登录..."
    logout
    if [[ "$?" -ne "1" ]]; then
        case "${status}" in
            "2")
                echo "登陆服务器连接失败，请检测网络连接。"
                ;;
            "0")
                echo "登出失败。"
                printf "信息：\t${info}\n"
                ;;
        esac
        exit 0
    fi
    echo "登出成功"
    printf "信息：\t${info}\n"
    return 0
}

get_status() {
    echo "获取登录信息..."
    check_loginStatus
    if [[ "$?" -ne "1" ]]; then
        case "${status}" in
            "2")
                echo "登陆服务器连接失败，请检测网络连接。"
                ;;
            "0")
                echo "未登录"
                printf "信息：\t${info}\n"
                ;;
        esac
        exit 0
    fi
    printf "状态：\t已经登陆\n账户：\t${logoutUsername}\nISP：\t${logoutDomain}\nIP：\t${logoutIp}\n地点：\t${logoutLocation}\n时长：\t${logoutTimer}s\n"
    return 0
}


if [[ "$#" -gt "1" ]]; then
    echo "参数过多!"
    show_help
    exit 1
fi

if [[ "$#" -eq "0" ]]; then
    check_and_login
    exit 0
fi

case "$1" in
    "help")
        show_help
        exit 0;;
    "login")
        force_login
        exit 0;;
    "logout")
        force_logout
        exit 0;;
    "status")
        get_status
        exit 0;;
    *)
        echo "未知参数"
        show_help
        exit 1;;
esac
