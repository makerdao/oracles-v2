FROM ubuntu:18.04

RUN apt-get update && \
    apt-get install -y curl xz-utils git sudo net-tools && \
    apt-get clean

# Add the user nixuser for security reasons and for Nix
RUN useradd -ms /bin/bash omnia

# Nix requires ownership of /nix
RUN mkdir -m 0755 /nix && \
    chown omnia /nix

# Add user to sudoers
RUN echo "omnia     ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Change docker user to omnia
USER omnia

# Change our working directory to $HOME
WORKDIR /home/omnia

# Install nix
RUN curl -L https://nixos.org/nix/install | sh

# Set some environment variables for Docker and Nix
ENV USER=omnia \
    NIX_LINK=$HOME/.nix-profile \
    PATH="/home/omnia/.nix-profile/bin:${PATH}" \
    NIX_PROFILES="/nix/var/nix/profiles/default /home/omnia/.nix-profile"

# Add Maker build cache
RUN nix run -f https://cachix.org/api/v1/install cachix -c cachix use maker

# Copy Omnia source code inside the container
COPY . .

# Give exec permission to setup scripts
RUN sudo chmod a+x *.sh

# Install Omnia and dependencies
RUN nix-env -i --verbose -f .

# Setup and start Omnia and SSB
EXPOSE 8007
EXPOSE 8988
ENTRYPOINT [ "./docker-entrypoint.sh" ]
# CMD [ "feed" ]

# CMD ["/usr/bin/supervisord", "-c", "/home/omnia/supervisord.conf"]
