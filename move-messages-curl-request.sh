#!/bin/sh

set -x

# -H 'Connection: keep-alive' \
# -H 'authorization: Basic Z3Vlc3Q6Z3Vlc3Q=' \
# -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.66 Safari/537.36' \
# -H 'Accept: */*' \
# -H 'Origin: http://localhost:15672' \
# -H 'Sec-Fetch-Site: same-origin' \
# -H 'Sec-Fetch-Mode: cors' \
# -H 'Sec-Fetch-Dest: empty' \
# -H 'Referer: http://localhost:15672/' \
# -H 'Accept-Language: en-US,en;q=0.9' \
# -H 'Cookie: _ga=GA1.1.482299397.1591743581; notice_behavior=none; m=2258:Z3Vlc3Q6Z3Vlc3Q%253D' \
# --compressed

curl 'http://localhost:15672/api/parameters/shovel/%2F/Move%20from%20test-1' -vu 'guest:guest' \
  -X 'PUT' \
  -H 'content-type: application/json' \
  --data-binary '{"component":"shovel","vhost":"/","name":"Move from test-1","value":{"src-uri":"amqp:///%2F","src-queue":"test-1","src-protocol":"amqp091","src-prefetch-count":1000,"src-delete-after":"queue-length","dest-protocol":"amqp091","dest-uri":"amqp:///%2F","dest-add-forward-headers":false,"ack-mode":"on-confirm","dest-queue":"retry_1"}}'
