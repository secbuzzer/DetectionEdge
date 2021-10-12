FROM fluent/fluentd:v1.9-1
MAINTAINER CSTI-Chenghan Lin

USER root

RUN apk add --no-cache --update --virtual .build-deps \
        sudo build-base ruby-dev \
 # cutomize following instruction as you wish
 && sudo gem install elasticsearch -v 7.13.1\
 && sudo gem install fluent-plugin-elasticsearch -v 5.0.4 \
 && sudo gem install fluent-plugin-tagged_udp \
                     fluent-plugin-multiprocess \
                     fluent-config-regexp-type \
 && sudo gem sources --clear-all \
 && apk del .build-deps \
 && rm -rf /home/fluent/.gem/ruby/2.5.0/cache/*.gem

COPY entrypoint.sh /bin/
USER root
