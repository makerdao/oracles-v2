FROM nixos/nix@sha256:909992c623023c15950f088185326b80012584127fbaef6366980d26a91c73d5

# Install dependencies
RUN apk add --update --no-cache bash git

# Setup Nix cache
RUN nix run -f https://cachix.org/api/v1/install cachix \
      -c cachix use maker; \
    nix-collect-garbage -d

# Copy Omnia source code inside the container
COPY omnia /src/omnia
COPY nix /src/nix

# Install Omnia runner and dependencies
RUN nix-env -i -f /src/nix/docker.nix --verbose; \
    nix-collect-garbage -d

# Add a non-root user
RUN adduser -D omnia
USER omnia
WORKDIR /home/omnia

# Set Omnia runner script as command
CMD [ "/nix/var/nix/profiles/default/bin/omnia-runner" ]
