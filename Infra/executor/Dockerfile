FROM alpine:3.20

RUN apk add --no-cache bash coreutils curl

WORKDIR /workspace

RUN adduser -D runner
USER runner

ENTRYPOINT ["/bin/bash", "-c"]
