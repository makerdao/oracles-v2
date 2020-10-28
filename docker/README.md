## Start Docker containers

Start by creating a `.env` file:

```sh
echo > .env ' 
SSB_NET_PORT=8008
SSB_WS_PORT=8988
EXT_IP=127.0.0.1
' 
```

Then start up your containers:

```sh
docker-compose up
```
