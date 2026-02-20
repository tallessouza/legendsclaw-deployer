#!/usr/bin/env bash
curl -k -s -w "\nHTTP_CODE:%{http_code}\n" -X POST "https://heilz2.talles.dev/api/users/admin/init" -H "Content-Type: application/json" -d '{"Username":"admin","Password":"888Lendario!"}'
