# Tailscale VPN Setup

Tailscale creates a secure encrypted tunnel between your local machine and the VPS.

## Why Tailscale?

- Zero-config VPN — no port forwarding needed
- End-to-end encryption
- Works behind NAT and firewalls
- Free for personal use (up to 100 devices)

## Setup Steps

### 1. Create Account
Go to [tailscale.com](https://tailscale.com) and create an account.

### 2. Install on VPS
```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```
Follow the URL to authenticate.

### 3. Install Locally
Download from [tailscale.com/download](https://tailscale.com/download) and install.

### 4. Note Your Tailnet ID
After both devices are connected:
```bash
tailscale status
```
Your tailnet ID appears in hostnames: `device-name.TAILNET_ID.ts.net`

### 5. Set Hostname
On the VPS:
```bash
tailscale set --hostname=your-gateway-name
```

### 6. Configure AIOSBot
In `setup.sh`, provide:
- `GATEWAY_HOSTNAME`: The tailscale hostname (e.g., `my-gateway`)
- `TAILNET_ID`: Your tailnet ID (e.g., `tail1234ab`)

The gateway URL becomes: `wss://my-gateway.tail1234ab.ts.net`

## Verify Connection

```bash
# From local machine
tailscale ping your-gateway-name

# Check gateway is reachable
curl https://your-gateway-name.TAILNET_ID.ts.net/health
```

## Troubleshooting

### Can't Connect
1. Check both devices are online: `tailscale status`
2. Verify Tailscale is running: `tailscale up`
3. Check firewall rules on VPS
4. Try: `tailscale ping target-hostname`

### Slow Connection
- Tailscale uses DERP relays initially, then establishes direct connection
- First connection may be slow; subsequent ones are faster
- Check: `tailscale netcheck`

### DNS Issues
If hostname resolution fails:
```bash
# Use IP directly (find it with)
tailscale status | grep your-gateway-name
```
