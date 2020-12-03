FROM eu.gcr.io/gardener-project/3rd/alpine:3.12.1

RUN apk --update add openssh
COPY sshd.sh /usr/local/bin/

RUN addgroup -S app && adduser -S --shell /bin/ash -G app app
USER app
WORKDIR /home/app

# Expose the regular ssh port
EXPOSE 2222
EXPOSE 10000-10100

ENTRYPOINT /usr/local/bin/sshd.sh