FROM ubuntu:bionic

# public apt-get mirrors are terribly slow if your network supports ipv6
# so we need to force apt to use ipv4
# https://ubuntuforums.org/showthread.php?t=2349892
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential \
        ca-certificates \
        dnsutils \
        git \
        libluajit-5.1-2 \
	libssl-dev \
        # libyaml-dev is needed to install lyaml
        libyaml-dev \
        luarocks \
        # for installing the add-apt-repository command
        software-properties-common \
        unzip \
        wget

# Install openresty from openresty's public APT repo
RUN wget -qO - https://openresty.org/package/pubkey.gpg | apt-key add -
RUN add-apt-repository -y "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main"

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y openresty

# Manually install dumb-init as it's not in the public APT repo
RUN wget https://github.com/Yelp/dumb-init/releases/download/v1.2.1/dumb-init_1.2.1_amd64.deb
RUN dpkg -i dumb-init_*.deb

RUN apt-get clean

# We directly pin both lua dependencies to allow for reproducible
# deploy builds.
RUN luarocks install luasec 0.7-1
RUN luarocks install lyaml 6.2.2-1
RUN luarocks install luasocket 3.0rc1-2
RUN luarocks install lua-resty-http 0.12-0

RUN mkdir -p /code
WORKDIR /code

RUN chown -R nobody:nogroup /code /usr/local/openresty

# See https://github.com/moby/moby/issues/2259
# This folder is used as a volume in itests
RUN mkdir -p /var/log/nginx
RUN chown -R nobody:nogroup /var/log/nginx

ADD . /code
USER nobody

# Rewrite SIGTERM(15) to SIGQUIT(3) to let Nginx shut down gracefully
CMD ["dumb-init", "/usr/local/openresty/nginx/sbin/nginx", "-c", "/code/nginx.conf"]
# vim: syntax=dockerfile
