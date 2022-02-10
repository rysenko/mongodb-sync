FROM alpine:edge

RUN apk add --no-cache bash mongodb-tools py-pip && \
  pip install awscli && \
  mkdir /backup

ENV CRON_TIME="0 0 * * *"
ENV S3_PATH=mongodb
ENV AWS_DEFAULT_REGION=us-east-1

ADD docker_entrypoint.sh /docker_entrypoint.sh
ADD backup.sh /backup.sh
ADD restore.sh /restore.sh
ADD sync.sh /sync.sh

VOLUME ["/backup"]

ENTRYPOINT ["/docker_entrypoint.sh"]

CMD ["sync"]
