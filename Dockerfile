FROM centos:latest
MAINTAINER Rohith <gambol99@gmail.com>

ENV KONG_VERSION 0.9.1

RUN yum install -y https://github.com/Mashape/kong/releases/download/${KONG_VERSION}/kong-${KONG_VERSION}.el7.noarch.rpm && \
    yum clean all

ADD assets/kong.conf /etc/kong/kong.conf
ADD assets/templates /etc/kong/templates
ADD docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE 8000 8443 8001

ENTRYPOINT [ "/docker-entrypoint.sh"]
