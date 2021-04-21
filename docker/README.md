## Production environments

1) Create a `.env` file and fill missing values:
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
   ```

2) Start up your containers:
   ```sh
   docker-compose up -f docker-compose.prod.yml
   ```

## Development environment

### First-time configuration

1) Start all containers:
    ```sh
    docker-compose up -f docker-compose.dev.yml
    ```

2) Wait until all containers are ready, then generate `Scuttlebot` invitation:
    ```sh
    docker-compose -f docker-compose.dev.yml exec feed nix-shell /src/shell.nix --command "ssb-server invite.create 1"
    ```

3) Accept the invitation in relay container (the $INVITATION variable is the invitation generated in the previous step):
    ```sh
    docker-compose -f docker-compose.dev.yml exec relay nix-shell /src/shell.nix --command "ssb-server invite.accept $INVITATION"
    ```

### Stopping and resuming containers

To manage lifecycle of containers, standard `docker-compose` methods can be used:
```sh
docker-compose -f docker-compose.dev.yml start
docker-compose -f docker-compose.dev.yml stop
```
