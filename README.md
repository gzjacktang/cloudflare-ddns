# Cloudflare DDNS

使用 Bash 调用 Cloudflare API v4 更新动态 DNS，避免无必要的更新请求，并支持 IPv4（A）与 IPv6（AAAA）记录。

----

创建 Cloudflare API 令牌，请转到 https://dash.cloudflare.com/profile/api-tokens 并按照以下步骤操作：

1. 单击创建令牌
2. 为令牌提供一个名称，例如，`cloudflare-ddns`
3. 授予令牌以下权限：
    * 区域 - 区域 - 读取
    * 区域 - 区域设置 - 读取
    * 区域 - DNS - 编辑
4. 将区域资源设置为：
    * 包括 - 特定区域 - 选择你想设置的域名

----
![image.png](https://i.loli.net/2021/11/13/OMpjhUyubrwN6Lk.png)

----
 

## 基础版本

1. 在 Cloudflare 中添加要更新的 DNS 记录，例如 `home.example.com`。用于直连 VPS 时，将记录设为 **DNS only**（灰云）。
2. 下载脚本：

```
curl -fsSL https://raw.githubusercontent.com/gzjacktang/cloudflare-ddns/main/cf-v4-ddns.sh -o /root/cf-v4-ddns.sh && chmod +x /root/cf-v4-ddns.sh
```

3. 编辑脚本并填写配置：

```
vim /root/cf-v4-ddns.sh
```

```
# Cloudflare API Token；不使用 Global API Key，也不需要填写 CFUSER。
CFKEY=""

# 一级域名
CFZONE_NAME="example.com"

# 子域名前缀；也可填写完整域名
CFRECORD_NAME="home"

# IPv4 用 A；IPv6 用 AAAA
CFRECORD_TYPE="A"
```

API Token 已包含账号身份与权限，因此不需要 `CFUSER`。请只授予上面列出的最小权限。

4. 首次执行，确认 Cloudflare DNS 记录已更新：

```
chmod 700 /root/cf-v4-ddns.sh
/root/cf-v4-ddns.sh
```

脚本不是常驻服务：每次运行时检查公网 IP，仅在 IP 变化时更新 Cloudflare，然后退出。

5. 使用 cron 持续定期执行。编辑定时任务：

```
crontab -e
```

每两分钟执行一次：

```cron
*/2 * * * * /root/cf-v4-ddns.sh >/dev/null 2>&1

# 如需日志，改用这一行：
*/2 * * * * /root/cf-v4-ddns.sh >> /var/log/cf-ddns.log 2>&1
```

保存后可用以下命令确认和查看日志：

```
crontab -l
tail -f /var/log/cf-ddns.log
```

`chmod 700` 会限制脚本仅由所有者读取和执行，避免 Cloudflare API Token 被其他本机用户读取。

## Telegram 通知版本

`cf-v4-ddns-tg.sh` 在 DNS 更新成功或失败时，会向 Telegram 发送通知。下载并编辑：

```
curl -fsSL https://raw.githubusercontent.com/gzjacktang/cloudflare-ddns/main/cf-v4-ddns-tg.sh -o /root/cf-v4-ddns-tg.sh && chmod +x /root/cf-v4-ddns-tg.sh
vim /root/cf-v4-ddns-tg.sh
```

在脚本顶部填写：

```
TG_ENABLE=true
TG_TOKEN="BotFather 创建机器人后获得的 Bot Token"
TG_CHAT_ID="接收通知的个人、群组或频道 Chat ID"
```

同时填写与基础版本相同的 `CFKEY`、`CFZONE_NAME`、`CFRECORD_NAME` 和 `CFRECORD_TYPE`。不需要通知时，设为 `TG_ENABLE=false`。

## 网络与端口

DDNS 脚本不监听端口，也不需要开放任何入站端口。它只需要服务器能主动通过 TCP 443 访问 Cloudflare API、IP 查询服务，以及（启用时）Telegram API。实际需要开放的端口取决于你部署的服务，例如 Web 服务通常为 80/443、SSH 通常为 22。



原作者：https://github.com/yulewang/cloudflare-api-v4-ddns
----
参考作者：https://github.com/aipeach/cloudflare-api-v4-ddns
----
参考网址：https://aipeach.gitbook.io/blogbackup/cloudflare-da-jian-ddns-jiao-ben-ban
----
