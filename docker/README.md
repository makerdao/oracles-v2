## Build Docker image

```sh
docker build -t makerdao/omnia ..
```

## Start Docker containers

First you need to creating a `.env` file to configure the Scuttlebot network:

```sh
cat > .env <<$
SSB_CAPS='{
  "shs": "BRsTikbASMIC6jAvsIbZy24Wd6IpLQ5FbEx1oyooGb8=",
  "sign": "HOGP1DI4ZybjiHYv7SvaadeSLSnt1MQ2bDo2v7aszh0="
}'
SSB_INVITE=
SSB_NET_PORT=8008
SSB_WS_PORT=8988
EXT_IP=127.0.0.1
ETH_GAS=7000000
ETH_NET=kovan
INFURAKEY=
ETH_FROM=0x
ETH_PASSWORD=
ETH_KEY='{}'
$
```

Then start up your containers:

```sh
docker-compose up
```
