#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Automatically update your CloudFlare DNS record to the IP, Dynamic DNS


# ================= Telegram通知配置 =================

TG_ENABLE=true

TG_TOKEN=""

TG_CHAT_ID=""


send_tg() {

    [ "$TG_ENABLE" != "true" ] && return

    curl -s \
    -X POST \
    "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    -d "chat_id=${TG_CHAT_ID}" \
    --data-urlencode "text=$1" \
    >/dev/null 2>&1

}



# ================= Cloudflare配置 =================


# API token
CFKEY=""


# Zone name
CFZONE_NAME=""


# Hostname
CFRECORD_NAME=""


# Record type
CFRECORD_TYPE="A"

# TTL
CFTTL=120


# Force update
FORCE=false



# get parameter

while getopts k:h:z:t:f: opts; do

  case ${opts} in

    k) CFKEY=${OPTARG} ;;

    h) CFRECORD_NAME=${OPTARG} ;;

    z) CFZONE_NAME=${OPTARG} ;;

    t) CFRECORD_TYPE=${OPTARG} ;;

    f) FORCE=${OPTARG} ;;
    *) exit 2 ;;

  esac

done

if [ "$CFRECORD_TYPE" = "A" ]; then
  WANIPSITE="https://ipv4.icanhazip.com"
elif [ "$CFRECORD_TYPE" = "AAAA" ]; then
  WANIPSITE="https://ipv6.icanhazip.com"
else
  echo "$CFRECORD_TYPE specified is invalid"
  exit 2
fi



if [ "$CFKEY" = "" ]; then

  echo "Missing API token"

  exit 2

fi



if [ "$CFRECORD_NAME" = "" ]; then

  echo "Missing hostname"

  exit 2

fi

if [ "$CFZONE_NAME" = "" ]; then

  echo "Missing zone name"

  exit 2

fi



# If hostname is not FQDN

if [ "$CFRECORD_NAME" != "$CFZONE_NAME" ] && [ -n "${CFRECORD_NAME##*"$CFZONE_NAME"}" ]; then

  CFRECORD_NAME="$CFRECORD_NAME.$CFZONE_NAME"

  echo " => Hostname is $CFRECORD_NAME"

fi



# Get current and old WAN ip

WAN_IP=$(curl -fsSL "$WANIPSITE")


WAN_IP_FILE=$HOME/.cf-wan_ip_$CFRECORD_NAME.txt



if [ -f "$WAN_IP_FILE" ]; then

  OLD_WAN_IP=$(cat "$WAN_IP_FILE")

else

  echo "No file, need IP"

  OLD_WAN_IP=""

fi



# IP unchanged exit

if [ "$WAN_IP" = "$OLD_WAN_IP" ] && [ "$FORCE" = false ]; then

  echo "WAN IP Unchanged"

  exit 0

fi
# Get zone_identifier & record_identifier

ID_FILE=$HOME/.cf-id_$CFRECORD_NAME.txt


if [ -f "$ID_FILE" ] && [ "$(wc -l < "$ID_FILE")" -eq 4 ] \
  && [ "$(sed -n '3p' "$ID_FILE")" == "$CFZONE_NAME" ] \
  && [ "$(sed -n '4p' "$ID_FILE")" == "$CFRECORD_NAME" ]; then


    CFZONE_ID=$(sed -n '1p' "$ID_FILE")

    CFRECORD_ID=$(sed -n '2p' "$ID_FILE")


else


    echo "Updating zone_identifier & record_identifier"


    CFZONE_ID=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" \
    -H "Authorization: Bearer $CFKEY" \
    -H "Content-Type: application/json" \
    | grep -Po '(?<="id":")[^"]*' | head -1)



    CFRECORD_ID=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME" \
    -H "Authorization: Bearer $CFKEY" \
    -H "Content-Type: application/json" \
    | grep -Po '(?<="id":")[^"]*' | head -1)



    {
      echo "$CFZONE_ID"
      echo "$CFRECORD_ID"
      echo "$CFZONE_NAME"
      echo "$CFRECORD_NAME"
    } > "$ID_FILE"


fi



# Update Cloudflare

echo "Updating DNS to $WAN_IP"



RESPONSE=$(curl -s -X PUT \
"https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
-H "Authorization: Bearer $CFKEY" \
-H "Content-Type: application/json" \
--data "{\"id\":\"$CFZONE_ID\",\"type\":\"$CFRECORD_TYPE\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WAN_IP\", \"ttl\":$CFTTL}")



if printf '%s' "$RESPONSE" | grep -q '"success":true'; then


    echo "Updated successfully!"


    # Telegram通知

    send_tg "✅ BOIL IP DDNS更新成功

域名:
$CFRECORD_NAME

类型:
$CFRECORD_TYPE

旧IP:
${OLD_WAN_IP:-无}

新IP:
$WAN_IP

时间:
$(date '+%F %T')

服务器:
$(hostname)"



    echo "$WAN_IP" > "$WAN_IP_FILE"


    exit 0


else


    echo 'Something went wrong :('

    echo "Response: $RESPONSE"



    # Telegram失败通知

    send_tg "❌ BOIL IP DDNS更新失败

域名:
$CFRECORD_NAME

时间:
$(date '+%F %T')

服务器:
$(hostname)

错误:
$RESPONSE"



    exit 1


fi
