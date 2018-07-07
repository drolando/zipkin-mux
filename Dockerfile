FROM ubuntu:bionic

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

RUN curl https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh > /usr/bin/wait-for-it.sh
RUN chmod +x /usr/bin/wait-for-it.sh

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

ADD . /code
USER nobody

CMD ["dumb-init", "/bin/sh", "-c", "wait-for-it.sh --timeout=90 cassandra-uswest1a:9042 -- \
        wait-for-it.sh --timeout=90 cassandra-uswest1b:9042 -- \
        /usr/local/openresty/nginx/sbin/nginx -c /code/nginx.conf"]
# vim: syntax=dockerfile
