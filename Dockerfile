FROM ruby:2.6.0-alpine3.8
ARG VCS_REF
ARG BUILD_DATE

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/tnwhitwell/traefik-pihole-dns-records" \
      org.label-schema.docker.cmd="docker run -v /var/run/docker.sock:/var/run/docker.sock -e TRAEFIK_CONTAINER_NAME=traefik -e PIHOLE_CONTAINER_NAME=pihole -e RULE_FILE_NAME=03-docker.conf tnwhitwell/traefik-pihole-dns-records" \
      org.label-schema.docker.params="TRAEFIK_CONTAINER_NAME=name of traefik container,PIHOLE_CONTAINER_NAME=name of pihole container,RULE_FILE_NAME=Name of the rule file to create in /etc/dnsmasq.d/ inside the container" \
      org.label-schema.schema-version="1.0" \
      maintainer="tom@whi.tw"

WORKDIR /app

COPY * /app/

RUN gem install bundler \
    && bundle install

CMD [ "/app/gen_docker_dns_records.rb" ]
