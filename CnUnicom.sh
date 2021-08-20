#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# Usage:
## wget --no-check-certificate https://raw.githubusercontent.com/mixool/HiCnUnicom/master/CnUnicom.sh && chmod +x CnUnicom.sh && bash CnUnicom.sh 
### bash <(curl -s https://raw.githubusercontent.com/mixool/HiCnUnicom/master/CnUnicom.sh) ${username} ${password}

# alias curl
alias curl='curl -m 10'

# user info: change them to yours or use parameters instead.
username="$1"
password="$2"

# 联通APP版本
unicom_version=8.8.2

# deviceId: 随机IMEI
deviceId=$(shuf -i 123456789012345-987654321012345 -n 1)

# 安卓手机端APP登录过的使用这个UA
UA="Mozilla/5.0 (Linux; Android 6.0.1; oneplus a5010 Build/V417IR; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/52.0.2743.100 Mobile Safari/537.36; unicom{version:android@$unicom_version,desmobile:$username};devicetype{deviceBrand:Oneplus,deviceModel:oneplus a5010}"

# 苹果手机端APP登录过的使用这个UA
#UA="ChinaUnicom4.x/176 CFNetwork/1121.2.2 Darwin/19.2.0"

# workdir
workdir="$(pwd)/CnUnicom_tmp"
[[ ! -d "$workdir" ]] && mkdir $workdir

function rsaencrypt() {
    cat > $workdir/rsa_public.key <<-EOF
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDc+CZK9bBA9IU+gZUOc6
FUGu7yO9WpTNB0PzmgFBh96Mg1WrovD1oqZ+eIF4LjvxKXGOdI79JRdve9
NPhQo07+uqGQgE4imwNnRx7PFtCRryiIEcUoavuNtuRVoBAm6qdB0Srctg
aqGfLgKvZHOnwTjyNqjBUxzMeQlEC2czEMSwIDAQAB
-----END PUBLIC KEY-----
EOF

    crypt_username=$(echo -n $username | openssl rsautl -encrypt -inkey $workdir/rsa_public.key -pubin -out >(base64 | tr "\n" " " | sed s/[[:space:]]//g))
    crypt_password=$(echo -n $password | openssl rsautl -encrypt -inkey $workdir/rsa_public.key -pubin -out >(base64 | tr "\n" " " | sed s/[[:space:]]//g))
}

function urlencode() {
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf "$c" | xxd -p -c1 | while read x;do printf "%%%s" "$x";done
        esac
    done
}

# 登录失败尝试修改以下这个appId的值为抓包获取的登录过的联通app
function login() {
    rsaencrypt
    cat > $workdir/signdata <<-EOF
isRemberPwd=true
&deviceId=$deviceId
&password=$(urlencode $crypt_password)
&simCount=0
&netWay=Wifi
&mobile=$(urlencode $crypt_username)
&yw_code=
&timestamp=$(date +%Y%m%d%H%M%S)
&appId=${appid}
&keyVersion=1
&deviceBrand=Oneplus
&pip=10.0.$(shuf -i 1-255 -n 1).$(shuf -i 1-255 -n 1)
&provinceChanel=general
&version=android%40$unicom_version
&deviceModel=oneplus%20a5010
&deviceOS=android6.0.1
&deviceCode=$deviceId
EOF

    # cookie
    #curl -X POST -sA "$UA" -b $workdir/cookie -c $workdir/cookie "https://m.client.10010.com/mobileService/customer/query/getMyUnicomDateTotle.htm?yw_code=&mobile=$username&version=android%40$unicom_version" | grep -oE "infoDetail" >/dev/null && status=0 || status=1
    #[[ $status == 0 ]] && echo "cookies登录1*******${username:0-4}成功"
    
    #if [[ $status == 1 ]]; then
        curl -X POST -sA "$UA" -c $workdir/cookie "https://m.client.10010.com/mobileService/logout.htm?&desmobile=$username&version=android%40$unicom_version" >/dev/null
        curl -sA "$UA" -b $workdir/cookie -c $workdir/cookie -d @$workdir/signdata "https://m.client.10010.com/mobileService/login.htm" >/dev/null
        token=$(cat $workdir/cookie | grep -E "a_token" | awk  '{print $7}')
        [[ "$token" = "" ]] && echo "Error, login failed." && echo "cmd for clean: rm -rf $workdir" && exit 1
        echo "密码登录1*******${username:0-4}成功"
    #fi
}

#function openChg() {
    # 每月一号办理解除40G封顶业务
    #[[ "$(date "+%d")" == "01" ]] || return 0
    #echo; echo $(date) starting dingding OpenChg...
    #curl -sA "$UA" -b $workdir/cookie --data "querytype=02&opertag=0" "https://m.client.10010.com/mobileService/businessTransact/serviceOpenCloseChg.htm" >/dev/null
#}

function membercenter() {
    echo; echo $(date) starting membercenter...
    
    #获取文章和评论生成数组数据
    NewsListId=($(curl -X POST -sA "$UA" -b $workdir/cookie --data "pageNum=1&pageSize=10&reqChannel=00" https://m.client.10010.com/commentSystem/getNewsList | grep -oE "id\":\"[^\"]*" | awk -F[\"] '{print $NF}' | tr "\n" " "))
    comtId=($(curl -X POST -sA "$UA" -b $workdir/cookie --data "id=${NewsListId[0]}&pageSize=10&pageNum=1&reqChannel=quickNews" -e "https://img.client.10010.com/kuaibao/detail.html?pageFrom=newsList&id=${NewsListId[0]}" https://m.client.10010.com/commentSystem/getCommentList | grep -oE "id\":\"[^\"]*" | awk -F[\"] '{print $NF}' | tr "\n" " "))
    nickId=($(curl -X POST -sA "$UA" -b $workdir/cookie --data "id=${NewsListId[0]}&pageSize=10&pageNum=1&reqChannel=quickNews" -e "https://img.client.10010.com/kuaibao/detail.html?pageFrom=newsList&id=${NewsListId[0]}" https://m.client.10010.com/commentSystem/getCommentList | grep -oE "nickName\":\"[^\"]*" | awk -F[\"] '{print $NF}' | tr "\n" " "))
    Referer="https://img.client.10010.com/kuaibao/detail.html?pageFrom=${NewsListId[0]}"
   
    #评论点赞
    for((i = 0; i < ${#comtId[*]}; i++)); do
        curl -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=02&pointType=02&reqChannel=quickNews&reqId=${comtId[i]}&praisedMobile=${nickId[i]}&newsId=${NewsListId[0]}" -e "$Referer" https://m.client.10010.com/commentSystem/csPraise
        curl -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=02&pointType=01&reqChannel=quickNews&reqId=${comtId[i]}&praisedMobile=${nickId[i]}&newsId=${NewsListId[0]}" -e "$Referer" https://m.client.10010.com/commentSystem/csPraise | grep -oE "growScore\":\"0\"" >/dev/null && break
    done
    
    #文章点赞
    for((i = 0; i <= ${#NewsListId[*]}; i++)); do
        curl -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=01&pointType=02&reqChannel=quickNews&reqId=${NewsListId[i]}" https://m.client.10010.com/commentSystem/csPraise
        curl -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=01&pointType=01&reqChannel=quickNews&reqId=${NewsListId[i]}" https://m.client.10010.com/commentSystem/csPraise | grep -oE "growScore\":\"0\"" >/dev/null && break
    done
    
    #文章评论
    newsTitle="$(curl -X POST -sA "$UA" -b $workdir/cookie --data "newsId=${NewsListId[1]}&reqChannel=quickNews&isClientSide=0&pageFrom=newsList" -e "$Referer" https://m.client.10010.com/commentSystem/getNewsDetails | grep -oE "mainTitle\":\"[^\"]*" | awk -F[\"] '{print $NF}')"
    subTitle="$(curl -X POST -sA "$UA" -b $workdir/cookie --data "newsId=${NewsListId[1]}&reqChannel=quickNews&isClientSide=0&pageFrom=newsList" -e "$Referer" https://m.client.10010.com/commentSystem/getNewsDetails | grep -oE "subTitle\":\"[^\"]*" | awk -F[\"] '{print $NF}')"
    for((i = 0; i <= 5; i++)); do
        data="id=${NewsListId[1]}&newsTitle=$(urlencode $newsTitle)&commentContent=$RANDOM&upLoadImgName=&reqChannel=quickNews&subTitle=$(urlencode $subTitle)&belongPro=098"
        mycomtId="$(curl -X POST -sA "$UA" -b $workdir/cookie --data "$data" -e "$Referer" https://m.client.10010.com/commentSystem/saveComment | grep -oE "id\":\"[^\"]*" | awk -F[\"] '{print $NF}')"
        curl -X POST -sA "$UA" -b $workdir/cookie --data "type=01&reqId=$mycomtId&reqChannel=quickNews" -e "$Referer" https://m.client.10010.com/commentSystem/delDynamic
    done
    
    #每月一次账单查询
    if [[ "$(date "+%d")" == "01" ]]; then
        curl -sLA "$UA" -b $workdir/cookie -c $workdir/cookie.HistoryBill --data "yw_code=&desmobile=$username&version=android@$unicom_version" "https://m.client.10010.com/mobileService/common/skip/queryHistoryBill.htm?mobile_c_from=home" >/dev/null
        curl -sLA "$UA" -b $workdir/cookie.HistoryBill --data "operateType=0&bizCode=1000210003&height=889&width=480" "https://m.client.10010.com/mobileService/query/querySmartBizNew.htm?" >/dev/null
        curl -sLA "$UA" -b $workdir/cookie.HistoryBill --data "systemCode=CLIENT&transId=&userNumber=$username&taskCode=TA52554375&finishTime=$(date +%Y%m%d%H%M%S)" "https://act.10010.com/signinAppH/limitTask/limitTime" >/dev/null
    fi

    #每日一次余量查询
    curl -sLA "$UA" -b $workdir/cookie -c $workdir/cookie.LeavePackage --data "desmobile=$username&version=android@$unicom_version" "https://m.client.10010.com/mobileService/common/skip/queryLeavePackage.htm" >/dev/null
    curl -sLA "$UA" -b $workdir/cookie.LeavePackage --data "operateType=0&bizCode=1000210026&height=776&width=480" "https://m.client.10010.com/mobileService/query/querySmartBizNew.htm?" >/dev/null
    curl -sLA "$UA" -b $workdir/cookie.LeavePackage --data "type=0" "https://m.client.10010.com/mobileService/grow/marginCheck.htm"
    
    #签到
    Referer="https://img.client.10010.com/activitys/member/index.html"
    data="yw_code=&desmobile=$username&version=android@$unicom_version"
    curl -sLA "$UA" -b $workdir/cookie -c $workdir/cookie.SigninActivity -e "$Referer" "https://act.10010.com/SigninApp/signin/querySigninActivity.htm?$data" >/dev/null
    Referer="https://act.10010.com/SigninApp/signin/querySigninActivity.htm?$data"
    curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity -e "$Referer" "https://act.10010.com/SigninApp/signin/daySign?vesion=0.$(shuf -i 1234567890123456-9876543210654321 -n 1)"
    echo
    curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity -e "$Referer" "https://act.10010.com/SigninApp/signin/todaySign"
    echo
    curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity -e "$Referer" "https://act.10010.com/SigninApp/signin/addIntegralDA"
    
    ##三次金币抽奖， 每日最多可花费金币执行十三次
    usernumberofjsp=$(curl -sA "$UA" -b $workdir/cookie.SigninActivity https://m.client.10010.com/dailylottery/static/textdl/userLogin | grep -oE "encryptmobile=\w*" | awk -F"encryptmobile=" '{print $2}'| head -n1)
    for((i = 1; i <= 3; i++)); do
        [[ $i -gt 3 ]] && curl -sA "$UA" -b $workdir/cookie.SigninActivity --data "goldnumber=10&banrate=10&usernumberofjsp=$usernumberofjsp" https://m.client.10010.com/dailylottery/static/doubleball/duihuan >/dev/null; sleep 1
        curl -sA "$UA" -b $workdir/cookie.SigninActivity --data "usernumberofjsp=$usernumberofjsp&flag=convert" https://m.client.10010.com/dailylottery/static/doubleball/choujiang | grep -qE "用户机会次数不足" && break
    done
    echo; echo goldTotal：$(curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity -e "$Referer" "https://act.10010.com/SigninApp/signin/getGoldTotal?vesion=0.$(shuf -i 1234567890123456-9876543210654321 -n 1)")
    
    ##积分抽奖首次免费，之后领300奖励积分兑换再抽奖,最多三十次
    curl -sLA "$UA" -b $workdir/cookie "https://m.client.10010.com/welfare-mall-front/mobile/winter/getpoints/v1"
    curl -X POST -sLA "$UA" -b $workdir/cookie --data "from=$(shuf -i 12345678901-98765432101 -n 1)" "https://m.client.10010.com/welfare-mall-front/mobile/winterTwo/getIntegral/v1"

    curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity --data "usernumberofjsp=$usernumberofjsp&flag=convert" http://m.client.10010.com/dailylottery/static/integral/choujiang
    #for((i = 1; i <= 15; i++)); do
        #echo . && curl -sA "$UA" -b $workdir/cookie.SigninActivity --data "goldnumber=10&banrate=30&usernumberofjsp=$usernumberofjsp" http://m.client.10010.com/dailylottery/static/integral/duihuan >/dev/null; sleep 1
        #curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity --data "usernumberofjsp=$usernumberofjsp&flag=convert" http://m.client.10010.com/dailylottery/static/integral/choujiang | grep -qE "用户机会次数不足" && break
    #done
    
    # 游戏频道签到积分 每日1积分
    curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity --data "methodType=iOSIntegralGet&gameLevel=1&deviceType=iOS" "https://m.client.10010.com/producGameApp"
    
    # 游戏奖励积分签到
    echo; curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity --data "methodType=signin" https://m.client.10010.com/producGame_signin

    # 游戏宝箱
    curl -X POST -sA "$UA"  -b $workdir/cookie.SigninActivity -c $workdir/cookie.xybx --data "thirdUrl=https%3A%2F%2Fimg.client.10010.com%2Fshouyeyouxi%2Findex.html%23%2Fyouxibaoxiang" https://m.client.10010.com/mobileService/customer/getShareRedisInfo.htm >/dev/null
    echo; curl -X POST -sA "$UA" -b $workdir/cookie.xybx --data "methodType=reward&deviceType=Android&clientVersion=$unicom_version&isVideo=N" https://m.client.10010.com/game_box
    #宝箱任务100M
    echo; curl -sA "$UA" -b $workdir/cookie.xybx --data "methodType=taskGetReward&deviceType=Android&clientVersion=$unicom_version&taskCenterId=98" https://m.client.10010.com/producGameTaskCenter
    ##游戏宝箱翻倍
    echo; curl -X POST -sA "$UA" -b $workdir/cookie.xybx --data "methodType=reward&deviceType=Android&clientVersion=$unicom_version&isVideo=Y" https://m.client.10010.com/game_box
    
    #沃之树浇水
    curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity -c $workdir/cookie.wotree --data "thirdUrl=https%3A%2F%2Fimg.client.10010.com%2Fmactivity%2FwoTree%2Findex.html%23%2F" https://m.client.10010.com/mobileService/customer/getShareRedisInfo.htm >/dev/null
    Referer="https://img.client.10010.com/mactivity/woTree/index.html"
    curl -X POST -sA "$UA" -b $workdir/cookie.wotree -c $workdir/cookie.wotree -e "$Referer" https://m.client.10010.com/mactivity/mailb/isNewLetter.htm >/dev/null
    curl -X POST -sA "$UA" -b $workdir/cookie.wotree -c $workdir/cookie.wotree -e "$Referer" https://m.client.10010.com/mactivity/task/bord.htm >/dev/null
    curl -X POST -sA "$UA" -b $workdir/cookie.wotree -c $workdir/cookie.wotree -e "$Referer" https://m.client.10010.com/mactivity/arbordayJson/index.htm >/dev/null
    curl -X POST -sA "$UA" -b $workdir/cookie.wotree -c $workdir/cookie.wotree -e "$Referer" https://m.client.10010.com/mactivity/arbordayJson/getChanceByIndex.htm?index=0 >/dev/null
    curl -X POST -sA "$UA" -b $workdir/cookie.wotree -c $workdir/cookie.wotree -e "$Referer" https://m.client.10010.com/mactivity/stealingEnergy/engerSign.htm >/dev/null
    echo; curl -X POST -sA "$UA" -b $workdir/cookie.wotree -c $workdir/cookie.wotree -e "$Referer" https://m.client.10010.com/mactivity/arbordayJson/arbor/3/0/3/grow.htm | grep -oE "addedValue\":[0-9]"
    
    #获得流量
    for((i = 1; i <= 3; i++)); do
        curl -X POST -sA "$UA" -b $workdir/cookie --data "stepflag=22" https://act.10010.com/SigninApp/mySignin/addFlow >/dev/null; sleep 5
        curl -X POST -sA "$UA" -b $workdir/cookie --data "stepflag=23" https://act.10010.com/SigninApp/mySignin/addFlow | grep -oE "reason\":\"01\"" >/dev/null && break
    done
}

function jfdouble() {
    echo; echo $(date) 开始 积分翻倍...
    
    #签到
    Referer="https://img.client.10010.com/activitys/member/index.html"
    data="yw_code=&desmobile=$username&version=android@$unicom_version"
    curl -sLA "$UA" -b $workdir/cookie -c $workdir/cookie.SigninActivity -e "$Referer" "https://act.10010.com/SigninApp/signin/querySigninActivity.htm?$data" >/dev/null
    Referer="https://act.10010.com/SigninApp/signin/querySigninActivity.htm?$data"
    ##签到视频翻倍赠送积分
    echo
    curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity -e "$Referer" "https://act.10010.com/SigninApp/signin/bannerAdPlayingLogo"
}

function main() {
    #sleep $(shuf -i 1-10800 -n 1)
    login
    membercenter
    jfdouble
    #openChg
    #rm -rf $workdir
    echo; echo $(date) 1*******${username:0-4} Accomplished.  Thanks!
}
function membercenter() {
    echo ${all_parameter[*]} | grep -qE "membercenter" || return 0
    echo && echo starting membercenter...
    
    # 获取文章和评论生成数组数据
    NewsListId=($(curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "pageNum=1&pageSize=10&reqChannel=00" https://m.client.10010.com/commentSystem/getNewsList | grep -oE "id\":\"[^\"]*" | awk -F[\"] '{print $NF}' | tr "\n" " "))
    comtId=($(curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "id=${NewsListId[0]}&pageSize=10&pageNum=1&reqChannel=quickNews" -e "https://img.client.10010.com/kuaibao/detail.html?pageFrom=newsList&id=${NewsListId[0]}" https://m.client.10010.com/commentSystem/getCommentList | grep -oE "id\":\"[^\"]*" | awk -F[\"] '{print $NF}' | tr "\n" " "))
    nickId=($(curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "id=${NewsListId[0]}&pageSize=10&pageNum=1&reqChannel=quickNews" -e "https://img.client.10010.com/kuaibao/detail.html?pageFrom=newsList&id=${NewsListId[0]}" https://m.client.10010.com/commentSystem/getCommentList | grep -oE "nickName\":\"[^\"]*" | awk -F[\"] '{print $NF}' | tr "\n" " "))
    Referer="https://img.client.10010.com/kuaibao/detail.html?pageFrom=${NewsListId[0]}"
   
    # 评论点赞后取消点赞
    for ((i = 0; i <= 5; i++)); do
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=02&pointType=01&reqChannel=quickNews&reqId=${comtId[i]}&praisedMobile=${nickId[i]}&newsId=${NewsListId[0]}" -e "$Referer" https://m.client.10010.com/commentSystem/csPraise >$workdir/csPraise.log
        cat $workdir/csPraise.log | grep -oE "growScore\":\"[0-9]+"; cat $workdir/csPraise.log | grep -qE "growScore\":\"0\"" && break
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=02&pointType=02&reqChannel=quickNews&reqId=${comtId[i]}&praisedMobile=${nickId[i]}&newsId=${NewsListId[0]}" -e "$Referer" https://m.client.10010.com/commentSystem/csPraise >/dev/null
    done
    
    # 文章点赞后取消点赞
    for ((i = 0; i <= 5; i++)); do
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=01&pointType=01&reqChannel=quickNews&reqId=${NewsListId[i]}" https://m.client.10010.com/commentSystem/csPraise >$workdir/csPraise.log
        cat $workdir/csPraise.log | grep -oE "growScore\":\"[0-9]+"; cat $workdir/csPraise.log | grep -qE "growScore\":\"0\"" && break
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=01&pointType=02&reqChannel=quickNews&reqId=${NewsListId[i]}" https://m.client.10010.com/commentSystem/csPraise >/dev/null
    done
    
    # 文章评论后删除评论
    newsTitle="$(curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "newsId=${NewsListId[1]}&reqChannel=quickNews&isClientSide=0&pageFrom=newsList" -e "$Referer" https://m.client.10010.com/commentSystem/getNewsDetails | grep -oE "mainTitle\":\"[^\"]*" | awk -F[\"] '{print $NF}')"
    subTitle="$(curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "newsId=${NewsListId[1]}&reqChannel=quickNews&isClientSide=0&pageFrom=newsList" -e "$Referer" https://m.client.10010.com/commentSystem/getNewsDetails | grep -oE "subTitle\":\"[^\"]*" | awk -F[\"] '{print $NF}')"
    for ((i = 0; i <= 5; i++)); do
        data="id=${NewsListId[1]}&newsTitle=$(urlencode $newsTitle)&commentContent=$RANDOM&upLoadImgName=&reqChannel=quickNews&subTitle=$(urlencode $subTitle)&belongPro=098"
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "$data" -e "$Referer" https://m.client.10010.com/commentSystem/saveComment >$workdir/csPraise.log
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "type=01&reqId=$(cat $workdir/csPraise.log | grep -oE "id\":\"[^\"]*" | awk -F[\"] '{print $NF}')&reqChannel=quickNews" -e "$Referer" https://m.client.10010.com/commentSystem/delDynamic >/dev/null
        cat $workdir/csPraise.log | grep -oE "growScore\":\"[0-9]+"; cat $workdir/csPraise.log | grep -qE "growScore\":\"0\"" && break
    done
    
    # 每月一次账单查询
    if [[ "$(date "+%d")" == "05" ]]; then
        echo && echo
        curl -m 10 -sLA "$UA" -b $workdir/cookie --data "yw_code=&desmobile=$username&version=android@$unicom_version" "https://m.client.10010.com/mobileService/common/skip/queryHistoryBill.htm?mobile_c_from=home" >/dev/null
        curl -m 10 -sLA "$UA" -b $workdir/cookie --data "systemCode=CLIENT&transId=&userNumber=$username&taskCode=TA52554375&finishTime=$(date +%Y%m%d%H%M%S)" "https://act.10010.com/signinAppH/limitTask/limitTime" >/dev/null
    fi

    # 每日一次余量查询
    echo && echo
    curl -m 10 -sLA "$UA" -b $workdir/cookie --data "desmobile=$username&version=android@$unicom_version" "https://m.client.10010.com/mobileService/common/skip/queryLeavePackage.htm" >/dev/null
    curl -m 10 -sLA "$UA" -b $workdir/cookie --data "type=0" "https://m.client.10010.com/mobileService/grow/marginCheck.htm" >/dev/null
    
    # 签到
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/signin/daySign?vesion=0.$(shuf -i 1234567890123456-9876543210654321 -n 1)"
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/signin/todaySign" | grep -oE "status\":\"[0-9]+"
    
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/signin/getContinuous"
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/signin/getIntegral"
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/signin/getGoldTotal"
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/signin/bannerAdPlayingLogo"
    ## 每日领取1G流量日包
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/doTask/finishVideo"
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/doTask/getTaskInfo"
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/doTask/getPrize"
    
    # 三次金币抽奖， 每日最多可花费金币执行十三次
    echo && echo
    usernumberofjsp=$(curl -m 10 -sA "$UA" -b $workdir/cookie https://m.client.10010.com/dailylottery/static/textdl/userLogin | grep -oE "encryptmobile=\w*" | awk -F"encryptmobile=" '{print $2}'| head -n1)
    for ((i = 1; i <= 3; i++)); do
        [[ $i -gt 3 ]] && curl -m 10 -sA "$UA" -b $workdir/cookie --data "goldnumber=10&banrate=10&usernumberofjsp=$usernumberofjsp" https://m.client.10010.com/dailylottery/static/doubleball/duihuan >/dev/null; sleep 1
        curl -m 10 -sA "$UA" -b $workdir/cookie --data "usernumberofjsp=$usernumberofjsp&flag=convert" https://m.client.10010.com/dailylottery/static/doubleball/choujiang | grep -oE "用户机会次数不足" && break
    done
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie -e "$Referer" "https://act.10010.com/SigninApp/signin/getGoldTotal?vesion=0.$(shuf -i 1234567890123456-9876543210654321 -n 1)" | grep -oE "goldTotal\":\"[0-9]+"
    
    # 积分抽奖首次免费，之后领300定向积分兑换再抽奖,最多三十次
    echo && echo
    curl -m 10 -X POST -sLA "$UA" -b $workdir/cookie --data "from=$(shuf -i 12345678901-98765432101 -n 1)" "https://m.client.10010.com/welfare-mall-front/mobile/winterTwo/getIntegral/v1"
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "usernumberofjsp=$usernumberofjsp&flag=convert" http://m.client.10010.com/dailylottery/static/integral/choujiang
    for ((i = 1; i <= 0; i++)); do
        curl -m 10 -sA "$UA" -b $workdir/cookie --data "goldnumber=10&banrate=30&usernumberofjsp=$usernumberofjsp" http://m.client.10010.com/dailylottery/static/integral/duihuan >/dev/null; sleep 1
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "usernumberofjsp=$usernumberofjsp&flag=convert" http://m.client.10010.com/dailylottery/static/integral/choujiang | grep -oE "用户机会次数不足" && break
    done
    
    # 每日领100定向积分
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "from=98880000020" https://m.client.10010.com/welfare-mall-front/mobile/integral/gettheintegral/v1
    
    # 游戏签到积分 每日1积分
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "methodType=iOSIntegralGet&gameLevel=1&deviceType=iOS" "https://m.client.10010.com/producGameApp"
    
    # 奖励积分
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "methodType=signin" https://m.client.10010.com/producGame_signin
    
    # 游戏宝箱
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "methodType=reward&deviceType=Android&clientVersion=$unicom_version&isVideo=N" https://m.client.10010.com/game_box
    echo && echo
    curl -m 10 -sA "$UA" -b $workdir/cookie --data "methodType=taskGetReward&taskCenterId=187&clientVersion=$unicom_version&deviceType=Android" https://m.client.10010.com/producGameTaskCenter
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "methodType=reward&deviceType=Android&clientVersion=$unicom_version&isVideo=Y" https://m.client.10010.com/game_box
    
    # 沃之树浇水，免费一次，服务器经常502错误，所以请求三次
    echo && echo
    for ((i = 1; i <= 3; i++)); do sleep 3 && curl -m 10 -X POST -sA "$UA" -b $workdir/cookie -e "https://img.client.10010.com/mactivity/woTree/index.html" https://m.client.10010.com/mactivity/arbordayJson/arbor/3/0/3/grow.htm | grep -oE "addedValue\":[0-9]" && break; done
    
    # 获得流量
    echo && echo
    for ((i = 1; i <= 3; i++)); do
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "stepflag=22" https://act.10010.com/SigninApp/mySignin/addFlow >/dev/null; sleep 3
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "stepflag=23" https://act.10010.com/SigninApp/mySignin/addFlow | grep -oE "reason\":\"01" && break
    done
}

function liulactive() {
    # 流量激活功能,可多次传入用于不同号码激活不同流量包: liulactive@d@ff80808166c5ee6701676ce21fd14716@13012341234 liulactive@w@20080615550312483@13800008888-13012341234@mygiftbag
    liulactivelist=($(echo ${all_parameter[*]} | grep -oE "liulactive@[mwd]@[0-9a-z@-]+" | tr "\n" " ")) && [[ ${#liulactivelist[*]} == 0 ]] && return 0
    echo && echo starting liulactive... && echo >$workdir/liulactive.info
    for ((i = 0; i < ${#liulactivelist[*]}; i++)); do  
        unset liulactive_run liulactive_only
        timeparId=$(echo ${liulactivelist[i]} | cut -f2 -d@)
        productId=$(echo ${liulactivelist[i]} | cut -f3 -d@)
        choosenos=$(echo ${liulactivelist[i]} | cut -f4 -d@)
        mygiftbag=$(echo ${liulactivelist[i]} | cut -f5 -d@)
        # 依照参数m|w|d来判断是否执行,分别代表每月一号和二号|每周一|每天
        [[ ${timeparId} == "m" ]] && [[ "$(date +%d)" == "01" ]] && liulactive_run=true
        [[ ${timeparId} == "m" ]] && [[ "$(date +%d)" == "02" ]] && liulactive_run=true
        [[ ${timeparId} == "w" ]] && [[ "$(date +%u)" == "1" ]]  && liulactive_run=true
        [[ ${timeparId} == "d" ]] && liulactive_run=true
        [[ "$liulactive_run" == "true" ]] || continue
        # 依照参数choosenos来判断是否是指定号码执行,未指定时全部号码均运行 | 如使用mygiftbag参数则必须指定号码
        [[ $choosenos != "" ]] && echo $choosenos | grep -qE "${username}" && liulactive_only=true
        [[ $choosenos == "" ]] && liulactive_only=true
        [[ "$liulactive_only" == "true" ]] || continue
        # 我的礼包-流量兑换-激活请求,当参数为null时不执行
        if [[ "$productId" != "null" ]]; then
            curl -m 10 -sA "$UA" -b $workdir/cookie -c $workdir/cookie_liulactive "https://m.client.10010.com/MyAccount/trafficController/myAccount.htm?flag=1&curl -m 10=https://m.client.10010.com/myPrizeForActivity/querywinninglist.htm?pageSign=1" >$workdir/liulactive.log
            liulactiveuserLogin="$(cat $workdir/liulactive.log | grep "refreshAccountTime" | grep -oE "[0-9_]+")"
            curl -m 10 -sA "$UA" -b $workdir/cookie_liulactive -c $workdir/cookie_liulactive "https://m.client.10010.com/MyAccount/MyGiftBagController/refreshAccountTime.htm?userLogin=$liulactiveuserLogin&accountType=FLOW" >/dev/null
            curl -m 10 -X POST -sA "$UA"  -b $workdir/cookie_liulactive -c $workdir/cookie_liulactive --data "thirdUrl=thirdUrl=https%3A%2F%2Fm.client.10010.com%2FMyAccount%2FtrafficController%2FmyAccount.htm" https://m.client.10010.com/mobileService/customer/getShareRedisInfo.htm >/dev/null
            Referer="https://m.client.10010.com/MyAccount/trafficController/myAccount.htm?flag=1&curl -m 10=https://m.client.10010.com/myPrizeForActivity/querywinninglist.htm?pageSign=1"
            curl -m 10 -X POST -sA "$UA" -e "$Referer" -b $workdir/cookie_liulactive -c $workdir/cookie_liulactive --data "productId=$productId&userLogin=$liulactiveuserLogin&ebCount=1000000&pageFrom=4" "https://m.client.10010.com/MyAccount/exchangeDFlow/exchange.htm?userLogin=$liulactiveuserLogin" >$workdir/liulactive.log2
            cat $workdir/liulactive.log2 | grep -oE ">.+<" | head -n 3 | awk -F'[><]' '{print $2,$4}' | tr "\n" " " >>$workdir/liulactive.info
        fi
        # 我的礼包-流量包-1G日包对应activeCode为73或者2534,当参数mygiftbag存在时运行: liulactive@d@ff80808166c5ee6701676ce21fd14716@13012341234@mygiftbag
        if [[ "$mygiftbag" != "" ]]; then
            sleep 120
            curl -m 10 -X POST -sA "$UA"  -b $workdir/cookie --data "typeScreenCondition=2&category=FFLOWPACKET&pageSign=1&CALLBACKURL=https%3A%2F%2Fm.client.10010.com%2FmyPrizeForActivity%2Fquerywinninglist.htm" http://m.client.10010.com/myPrizeForActivity/mygiftbag.htm >$workdir/libaollactive.log
            endtimeliststemp=($(cat $workdir/libaollactive.log | grep -A 50 -E "'(73|2534)','[a-zA-Z0-9]+" | grep -E "(onclick|boxBG_footer_leftTime)" | grep -oE "20[0-9]{2}-[0-9]{2}-[0-9]{2}" | sed "1~2d" | tr "\n" " "))
            endtimelistsince=($(for endtime in ${endtimeliststemp[*]}; do date -d "$endtime 23:59:59" +"%s"; done | tr "\n" " "))
            yesterdaytimesince=$(date -d "$(date +%Y-%m-%d -d "-1 days") 23:59:59" +"%s")
            # 优先激活临期的流量礼包
            mygiftbagtemp=($(cat $workdir/libaollactive.log | grep -oE "'(73|2534)','[a-zA-Z0-9]+" | sed -e "s/','/@/g" -e "s/^'//g"  | tr "\n" " "))
            mygiftbaglist=($(for ((j = 0; j < ${#mygiftbagtemp[*]}; j++)); do echo ${endtimelistsince[j]}@${mygiftbagtemp[j]}; done | awk -F@ -v yesterdaytimesince="$yesterdaytimesince" '$1 > yesterdaytimesince {print $0}' | sort | grep -oE "(73|2534)@[a-zA-Z0-9]+$" | tr "\n" " "))
            for ((j = 0; j < ${#mygiftbaglist[*]}; j++)); do
                curl -m 10 -X POST -sA "$UA"  -b $workdir/cookie --data "activeCode=${mygiftbaglist[j]%@*}&prizeRecordID=${mygiftbaglist[j]#*@}&userNumber=${username}" http://m.client.10010.com/myPrizeForActivity/queryPrizeDetails.htm >$workdir/libaollactive.log2
                cat $workdir/libaollactive.log2 | grep -A 15 "奖品状态" | grep -qE "(未激活|激活失败)" || continue
                libaollName=$(urlencode $(cat $workdir/libaollactive.log2 | grep "id=\"activeName" | cut -f4 -d\") | tr "a-z" "A-Z")
                curl -m 10 -X POST -sA "$UA"  -b $workdir/cookie --data "activeCode=${mygiftbaglist[j]%@*}&prizeRecordID=${mygiftbaglist[j]#*@}&activeName=$libaollName" http://m.client.10010.com/myPrizeForActivity/myPrize/activationFlowPackages.htm | grep -oE "activationlimit"  && echo 我的礼包-流量包-1G日包-激活失败 >>$workdir/liulactive.info && break
                sleep 120
                curl -m 10 -X POST -sA "$UA"  -b $workdir/cookie --data "activeCode=${mygiftbaglist[j]%@*}&prizeRecordID=${mygiftbaglist[j]#*@}&userNumber=${username}" http://m.client.10010.com/myPrizeForActivity/queryPrizeDetails.htm | grep -A 15 "奖品状态" | grep -qE "已激活" && echo 我的礼包-流量包-1G日包-激活成功 >>$workdir/liulactive.info && break
            done
        fi      
    done
}

function hfgoactive() {
    # 话费购活动，需传入参数 hfgoactive
    echo ${all_parameter[*]} | grep -qE "hfgoactive" || return 0
    echo && echo starting hfgoactive... && echo >$workdir/hfgoactive.info
    curl -m 10 -sLA "$UA" -b $workdir/cookie -c $workdir/cookie_hfgo "https://m.client.10010.com/mobileService/openPlatform/openPlatLineNew.htm?to_url=https://account.bol.wo.cn/cuuser/open/openLogin/hfgo&yw_code=&desmobile=${username}&version=android@${unicom_version}" >/dev/null
    # 每日签到并抽奖,抽奖免费3次,连续签到七天获得额外3次，每日签到有机会获取额外机会
    ACTID="$(curl -m 10 -X POST -sA "$UA" -b $workdir/cookie_hfgo --data "positionType=1" https://hfgo.wo.cn/hfgoapi/product/ad/list | grep -oE "atplottery[^?]*" | cut -f2 -d/)"
    echo $ACTID | grep -vE "[a-zA-Z0-9]+" && echo Unauthorized && return 1
    curl -m 10 -sLA "$UA" -b $workdir/cookie_hfgo -c $workdir/cookie_hfgo "https://hfgo.wo.cn/hfgoapi/cuuser/auth/autoLogin?redirectUrl=https://atp.bol.wo.cn/atplottery/${ACTID}?product=hfgo&ch=002&$(cat $workdir/cookie_hfgo | grep -oE "[^_]token.*" | sed s/[[:space:]]//g | sed "s/token/Authorization=/")" >/dev/null
    # 签到
    curl -m 10 -sA "$UA"  -b $workdir/cookie_hfgo https://atp.bol.wo.cn/atpapi/act/actUserSign/everydaySign?actId=1516 >$workdir/hfgoactivesign.log
    cat $workdir/hfgoactivesign.log
    cat $workdir/hfgoactivesign.log | grep -qE "Unauthorized" && return 1
    # 抽奖
    for ((i = 1; i <= 9; i++)); do
        echo && echo
        curl -m 10 -sA "$UA"  -b $workdir/cookie_hfgo "https://atp.bol.wo.cn/atpapi/act/lottery/start/v1/actPath/${ACTID}/0" >$workdir/lottery_hfgo.log
        cat $workdir/lottery_hfgo.log | grep -oE "抽奖次数已用完" && break
        cat $workdir/lottery_hfgo.log | grep -oE "Unauthorized" && break
        cat $workdir/lottery_hfgo.log | grep -oE "prizeName\":\"[^\"]*" | cut -f3 -d\" >>$workdir/hfgoactive.info
    done
    #
    cat $workdir/hfgoactive.info
}

function jifeninfo() {
    # 积分信息显示，需传入参数 jifeninfo
    echo ${all_parameter[*]} | grep -qE "jifeninfo" || return 0
    echo && echo starting jifeninfo...
    # 通信 奖励 定向 积分
    for ((i = 0; i < 5; i++)); do
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://m.client.10010.com/welfare-mall-front/mobile/show/bj2205/v2/Y" >$workdir/jifeninfo.log
        cat $workdir/jifeninfo.log | grep -qE "查询成功" && break || sleep 1
    done
    jfnumber=($(cat $workdir/jifeninfo.log | grep -oE "number\":\"[0-9]+" | grep -oE "[0-9]+" | tr "\n" " "))
    jfname=($(cat $workdir/jifeninfo.log | grep -oE "name\":\"[^\"]+" | cut -d\" -f3 | tr "\n" " "))
    # 总积分和将过期积分
    for ((i = 0; i < 5; i++)); do
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "reqsn=&reqtime=&cliver=&reqdata=" "https://m.client.10010.com/welfare-mall-front/mobile/show/queryUserTotalScore/v1" >$workdir/jifeninfo.log
        cat $workdir/jifeninfo.log | grep -qE "查询成功" && break || sleep 1
    done
    invalid=$(cat $workdir/jifeninfo.log | grep -oE "invalid\":[0-9]+" | grep -oE "[0-9]+")
    canUse=$(cat $workdir/jifeninfo.log | grep -oE "canUse\":[0-9]+" | grep -oE "[0-9]+")
    # 奖励积分详情
    for ((i = 0; i < 5; i++)); do
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "reqsn=&reqtime=&cliver=&reqdata=" "https://m.client.10010.com/welfare-mall-front/mobile/show/flDetail/v1/0" >$workdir/jifeninfo.log
        cat $workdir/jifeninfo.log | grep -qE "查询成功" && break || sleep 1
    done
    availablescore=$(cat $workdir/jifeninfo.log | grep -oE "availablescore\":\"[0-9]+" | grep -oE "[0-9]+")
    invalidscore=$(cat $workdir/jifeninfo.log | grep -oE "invalidscore\":\"[0-9]+" | grep -oE "[0-9]+")
    addScore=$(cat $workdir/jifeninfo.log | grep -oE "addScore\":\"[0-9]+" | grep -oE "[0-9]+")
    decrScore=$(cat $workdir/jifeninfo.log | grep -oE "decrScore\":\"[0-9]+" | grep -oE "[0-9]+")
    # 今日奖励积分
    today="$(date +%Y-%m-%d)" && todayscore=0
    todayscorelist=($(cat $workdir/jifeninfo.log | grep -oE "createTime\":\"$today[^}]*" | grep 'books_oper_type":"0"' | grep -oE "books_number\":[0-9]+" | grep -oE "[0-9]+" | tr "\n" " "))
    for ((i = 0; i < ${#todayscorelist[*]}; i++)); do todayscore=$((todayscore+todayscorelist[i])); done
    # 昨日奖励积分
    yesterday="$(date -d "1 days ago" +%Y-%m-%d)" && yesterdayscore=0
    yesterdayscorelist=($(cat $workdir/jifeninfo.log | grep -oE "createTime\":\"$yesterday[^}]*" | grep 'books_oper_type":"0"' | grep -oE "books_number\":[0-9]+" | grep -oE "[0-9]+" | tr "\n" " "))
    for ((i = 0; i < ${#yesterdayscorelist[*]}; i++)); do yesterdayscore=$((yesterdayscore+yesterdayscorelist[i])); done
    # info
    echo $(echo ${username:0:2}******${username:8}) 总积分-$canUse 通信积分-${jfnumber[0]} 奖励积分-${jfnumber[1]} 定向积分-${jfnumber[2]} 本月将过期积分:$invalid 本月将过期奖励积分:$invalidscore 本月新增奖励积分:$addScore 本月消耗奖励积分:$decrScore 昨日奖励积分:$yesterdayscore 今日奖励积分:$todayscore
}

function otherinfo() {
    # 需传入参数 otherinfo
    echo ${all_parameter[*]} | grep -qE "otherinfo" || return 0
    echo && echo starting otherinfo... && echo >$workdir/otherinfo.info
    # 套餐
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "mobile=$username" https://m.client.10010.com/mobileservicequery/operationservice/queryOcsPackageFlowLeftContent >$workdir/otherinfo.log
    addUpItemName=($(cat $workdir/otherinfo.log | grep -oE "addUpItemName\":\"[^\"]*" | cut -f3 -d\" | tr "\n" " "))
    endDate=($(cat $workdir/otherinfo.log | grep -oE "endDate\":\"[^\"]*" | cut -f3 -d\" | tr "\n" " "))
    remain=($(cat $workdir/otherinfo.log | grep -oE "remain\":\"[^\"]*" | cut -f3 -d\" | tr "\n" " "))
    for ((i = 0; i < ${#addUpItemName[*]}; i++)); do echo ${addUpItemName[i]}-${endDate[i]}-${remain[i]} >>$workdir/otherinfo.info; done
    # 话费
    curl -m 10 -X POST -sLA "$UA" -b $workdir/cookie --data "channel=client" https://m.client.10010.com/mobileservicequery/balancenew/accountBalancenew.htm >$workdir/otherinfo.log
    curntbalancecust=$(cat $workdir/otherinfo.log | grep -oE "curntbalancecust\":\"-?[0-9,]+\.[0-9]+" | cut -f3 -d\")
    realfeecust=$(cat $workdir/otherinfo.log | grep -oE "realfeecust\":\"-?[0-9,]+\.[0-9]+" | cut -f3 -d\")
    echo 可用余额:$curntbalancecust 实时话费:$realfeecust >>$workdir/otherinfo.info
    #
    cat $workdir/otherinfo.info
}

function freescoregift() {
    # 定向积分免费商品信息,需传入参数 freescoregift
    echo ${all_parameter[*]} | grep -qE "freescoregift" || return 0
    echo && echo starting freescoregift... && echo >$workdir/freescoregift.info
    # 积分商城限量免费领取商品
    big_SHELF_ID=8a29ac8975c327170175e40901610c77
    curl -m 10 -X POST -sLA "$UA" -b $workdir/cookie --data "reqsn=&reqtime=$(date +%s)$(shuf -i 100-999 -n 1)&cliver=&reqdata=%7B%7D" "https://m.client.10010.com/welfare-mall-front/mobile/show/getShelvesInfoDetail/v2?relevanceId=$big_SHELF_ID&sort=&category=2&goodsSkuId=undefined" >$workdir/freescoregift.log
    goods_NAME=($(cat $workdir/freescoregift.log | grep -oE "goods_NAME\":\"[^\"]+" | cut -f3 -d\" | tr "\n" " "))
    shop_INTEGRAL=($(cat $workdir/freescoregift.log | grep -oE "shop_INTEGRAL\":\"[^\"]+" | cut -f3 -d\" | tr "\n" " "))
    for ((i = 0; i < ${#goods_NAME[*]}; i++)); do echo ${goods_NAME[i]}-需要定向积分-${shop_INTEGRAL[i]} >>$workdir/freescoregift.info; done
    # 超级星期五定向积分免费商品页面
    curl -m 10 -X POST -sLA "$UA" -b $workdir/cookie https://m.client.10010.com/welfare-mall-front-activity/mobile/activity/getPointsMall/v1 >$workdir/freescoregift.log2
    #getPointsMallstock=($(cat $workdir/freescoregift.log2 | grep -oE "{[^{]*" | grep -E "tabName\":\"3#定向积分#免费领" | sed "/stock\":0,/d" | grep -oE "stock\":[0-9]+" | sed "s/\":/-/g" | tr "\n" " "))
    getPointsMallgoods=($(cat $workdir/freescoregift.log2 | grep -oE "{[^{]*" | grep -E "tabName\":\"3#定向积分#免费领" | sed "/stock\":0,/d" | grep -oE "goodsName\":\"[^\"]+" | cut -f3 -d\" | tr "\n" " "))
    [[ ${#getPointsMallgoods[*]} == 0 ]] && echo 超级星期五定向积分免费商品页面访问失败 >>$workdir/freescoregift.info || echo 超级星期五定向积分商品页面: >>$workdir/freescoregift.info
    for ((i = 0; i < ${#getPointsMallgoods[*]}; i++)); do echo ${getPointsMallstock[i]} ${getPointsMallgoods[i]} >>$workdir/freescoregift.info; done
}

function formatsendinfo() {
    # 格式化发送信息到文件供其它通知功能使用,sendsimple参数定义发送文件名,未传入该参数时发送详细信息
    echo ${all_parameter[*]} | grep -qE "sendsimple" && formatsendinfo_file="$workdir/formatsendinfosimple" || formatsendinfo_file="$workdir/formatsendinfoall"
    if $(echo ${all_parameter[*]} | grep -qE "sendsimple"); then
        echo ${userlogin_ook[u]} ${#userlogin_ook[*]} Accomplished. ${userlogin_err[u]} ${#userlogin_err[*]} Failed. >$formatsendinfo_file
        echo ${all_parameter[*]} | grep -qE "otherinfo"     && echo 可用余额:$curntbalancecust 实时话费:$realfeecust >>$formatsendinfo_file
        echo ${all_parameter[*]} | grep -qE "jifeninfo"     && echo 总积分-$canUse 通信积分-${jfnumber[0]} 奖励积分-${jfnumber[1]} 定向积分-${jfnumber[2]} 今日奖励积分:$todayscore >>$formatsendinfo_file
        echo ${all_parameter[*]} | grep -qE "hfgoactive"    && echo 话费购奖品: $(cat $workdir/hfgoactive.info | tail -n +2) >>$formatsendinfo_file
        echo ${all_parameter[*]} | grep -qE "freescoregift" && echo 定向积分免费商品数量:$(cat $workdir/freescoregift.info | tail -n +3 | grep -cv '^$') >>$formatsendinfo_file
        echo ${all_parameter[*]} | grep -qE "liulactive" && [[ -f $workdir/liulactive.info ]] && [[ $(cat $workdir/liulactive.info) != "" ]] && echo 流量激活: $(cat $workdir/liulactive.info) >>$formatsendinfo_file
    else
        echo ${userlogin_err[u]} ${#userlogin_err[*]} Failed. ${userlogin_ook[u]} ${#userlogin_ook[*]} Accomplished. >$formatsendinfo_file
        echo ${all_parameter[*]} | grep -qE "otherinfo" && cat $workdir/otherinfo.info >>$formatsendinfo_file
        echo ${all_parameter[*]} | grep -qE "jifeninfo" && echo $(echo ${username:0:2}******${username:8}) 总积分-$canUse 通信积分-${jfnumber[0]} 奖励积分-${jfnumber[1]} 定向积分-${jfnumber[2]} 本月将过期积分:$invalid 本月将过期奖励积分:$invalidscore 本月新增奖励积分:$addScore 本月消耗奖励积分:$decrScore 昨日奖励积分:$yesterdayscore 今日奖励积分:$todayscore >>$formatsendinfo_file
        echo ${all_parameter[*]} | grep -qE "hfgoactive" && cat $workdir/hfgoactive.info >>$formatsendinfo_file
        [[ $u == $((${#all_username_password[*]}-1)) ]] && echo ${all_parameter[*]} | grep -qE "freescoregift" && cat $workdir/freescoregift.info >>$formatsendinfo_file
        echo ${all_parameter[*]} | grep -qE "liulactive" && [[ -f $workdir/liulactive.info ]] && [[ $(cat $workdir/liulactive.info) != "" ]] && echo 流量激活: $(cat $workdir/liulactive.info) >>$formatsendinfo_file
    fi
    cat $formatsendinfo_file
}

function telegrambot() {
    # TG_BOT通知消息: 未设置相应传入参数时不执行,传入参数格式 token@*** chat_id@*** | google search: telegram bot token chat_id
    echo ${all_parameter[*]} | grep -qE "token@[a-zA-Z0-9:_-]+" && token="$(echo ${all_parameter[*]} | grep -oE "token@[a-zA-Z0-9:_-]+" | cut -f2 -d@)" || return 0
    echo ${all_parameter[*]} | grep -qE "chat_id@[0-9-]+" && chat_id="$(echo ${all_parameter[*]} | grep -oE "chat_id@[0-9-]+" | cut -f2 -d@)" || return 0
    echo && echo starting telegrambot...
    curl -m 10 -sX POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chat_id&text=$(cat $formatsendinfo_file)" >/dev/null
}

function jwks123push() {
    # jwks123 一键免费推送信息到手机
    echo ${all_parameter[*]} | grep -qE "jwks123token@[a-zA-Z0-9:_-]+" && jwks123token="$(echo ${all_parameter[*]} | grep -oE "jwks123token@[a-zA-Z0-9:_-]+" | cut -f2 -d@)" || return 0
    echo && echo starting jwks123push...
    curl -L -m 10 -sX POST "https://push.jwks123.cn/to/"  --data "{\"token\":\"$jwks123token\",\"msg\":\"$(cat $formatsendinfo_file)\"}" >/dev/null
}

function serverchan() {
    # serverchan旧版通知消息: sckey@************
    echo ${all_parameter[*]} | grep -qE "sckey@[a-zA-Z0-9:_-]+" && sckey="$(echo ${all_parameter[*]} | grep -oE "sckey@[a-zA-Z0-9:_-]+" | cut -f2 -d@)" || return 0
    echo && echo starting serverchan...
    curl -m 10 -sX POST "https://sc.ftqq.com/$sckey.send" -d "text=$(cat $formatsendinfo_file)" >/dev/null
}

function bark() {
    # bark通知消息: bark@************;bark推送不编码有换行推送不了，用tr空格替换了,推送效果极差
    echo ${all_parameter[*]} | grep -qE "bark@[a-zA-Z0-9:_-]+" && bark="$(echo ${all_parameter[*]} | grep -oE "bark@[a-zA-Z0-9:_-]+" | cut -f2 -d@)" || return 0
    echo && echo starting bark...
    curl -m 10 -sX POST "https://api.day.app/$bark/$(cat $formatsendinfo_file | tr "\n" " ")" >/dev/null
}

function main() {
    for ((u = 0; u < ${#all_username_password[*]}; u++)); do 
        sleep $(shuf -i 1-2 -n 1)
        username=${all_username_password[u]%@*} && password=${all_username_password[u]#*@}
        UA="Mozilla/5.0 (Linux; Android 11; MI 9 Build/RKQ1.200826.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/87.0.4280.141 Mobile Safari/537.36; unicom{version:android@$unicom_version,desmobile:$username};devicetype{deviceBrand:Xiaomi,deviceModel:MI 9}"
        workdir="${workdirbase}_${username}" && [[ ! -d "$workdir" ]] && mkdir -p $workdir
        userlogin && userlogin_ook[u]=$(echo ${username:0:2}******${username:8}) || { userlogin_err[u]=$(echo ${username:0:2}******${username:8}); continue; }
        membercenter
        liulactive
        hfgoactive
        jifeninfo
        otherinfo
        freescoregift
        # 通知
        jwks123push
        formatsendinfo
        telegrambot
        serverchan
        bark
    done
    echo && echo $(date) ${userlogin_err[*]} ${#userlogin_err[*]} Failed. ${userlogin_ook[*]} ${#userlogin_ook[*]} Accomplished.
    #rm -rf ${workdirbase}_*
    #username=13012341234 && unicom_version=8.0200 && workdirbase="/tmp/log/CnUnicom" && workdir="${workdirbase}_${username}" && UA="Mozilla/5.0 (Linux; Android 11; MI 9 Build/RKQ1.200826.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/87.0.4280.141 Mobile Safari/537.36; unicom{version:android@$unicom_version,desmobile:$username};devicetype{deviceBrand:Xiaomi,deviceModel:MI 9}"
}

main
