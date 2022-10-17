#!/bin/sh
if [[ -n "$HEADSCALE_CONFIG" ]]; then
  echo -e $HEADSCALE_CONFIG | tee /etc/headscale/config.yaml
fi

exec /bin/litestream replicate --exec "/bin/headscale serve"
