#!/usr/bin/env bash
docker service update --force portainer_portainer
sleep 30

dominio="heilz2.talles.dev"
user="admin"
pass="888Lendario"

payload=$(printf '{"Username":"%s","Password":"%s"}' "$user" "$pass")
echo "PAYLOAD: $payload"

response=$(curl -k -s --max-time 10 -X POST "https://${dominio}/api/users/admin/init" -H "Content-Type: application/json" -d "$payload" 2>/dev/null)
echo "RESPONSE: $response"

echo "$response" | grep -q '"Username"' && echo "MATCH" || echo "NO MATCH"
