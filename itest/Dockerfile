FROM ubuntu:bionic

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    python3-dev \
    python3-setuptools \
    python3-pip && \
    apt-get clean

RUN pip3 install -U pip wheel

RUN pip3 install \
    pytest \
    py-zipkin \
    PyYAML \
    requests

RUN curl https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh > /usr/bin/wait-for-it.sh
RUN chmod +x /usr/bin/wait-for-it.sh

RUN mkdir -p /code
WORKDIR /code

ADD . /code
RUN chmod 777 -R /code

ENTRYPOINT ["wait-for-it.sh", "--timeout=15", "zipkin-mux:9411", "--"]
