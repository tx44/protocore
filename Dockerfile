ARG GRPC_JAVA_VERSION=1.31.1

FROM alpine:latest AS base
RUN apk add --no-cache wget

# GO PLUGIN
#
# It is trivially fast to just compile our own optimized and stripped binary
# distribution of the go protoc plugin, so just do that instead of messing with
# finding a binary distribution we like.
FROM golang:1.15-alpine AS go-builder
RUN apk add --no-cache git upx
ENV GO111MODULE=on
RUN go get -ldflags="-s -w" \
    github.com/golang/protobuf/protoc-gen-go@v1.4.2 \
    github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc@v1.3.2
RUN upx /go/bin/*

# TYPESCRIPT PLUGIN ALTERNATIVE
#
# Written in NodeJS, so I don't see an obvious way around having node on the
# final image, but we can do this in a build stage to keep it concurrent and
# since we dont require NPM itself on the final version.
#
# Future of plugin: https://github.com/improbable-eng/ts-protoc-gen/issues/145
#
# UPDATE: use nexe to create an embedded single file version with node, so that
# we only need to worry about a single file on the final image. This seems to
# create a ~40mb file, whereas alpine nodejs claims to be ~26mb and the module
# itself is only ~1.5mb -- however having a single file makes it easier to deal
# with and UPX compress it later which will be smaller, so we deal with some
# upfront cost here.
FROM node:12-alpine AS ts-builder
RUN apk add --no-cache upx
RUN mkdir -p /dist
RUN npm install --unsafe-perm -g ts-protoc-gen@0.12.0 nexe@3.3.7
WORKDIR /usr/local/lib/node_modules/ts-protoc-gen/lib
RUN nexe \
    --output /dist/protoc-gen-ts \
    --target alpine-x64-12.9.1 \
    index.js
# RUN upx /dist/*
# ^^ some issues with strippping nexe binaries, TODO: resolve this
# https://github.com/nexe/nexe/issues/523

# NODE PLUGIN
FROM base AS node-builder
RUN mkdir -p /dist
# Otherwise download via `npm i grpc-tools`
RUN wget https://node-precompiled-binaries.grpc.io/grpc-tools/v1.9.1/linux-x64.tar.gz -O- | tar -xz --strip 1 -C /dist

# WEB PLUGIN
FROM base AS web-builder
RUN wget https://github.com/grpc/grpc-web/releases/download/1.2.0/protoc-gen-grpc-web-1.2.0-linux-x86_64 -O /protoc-gen-grpc-web
RUN chmod +x /protoc-gen-grpc-web

# JAVA PLUGIN
FROM base AS java-builder
ARG GRPC_JAVA_VERSION
RUN wget https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/${GRPC_JAVA_VERSION}/protoc-gen-grpc-java-${GRPC_JAVA_VERSION}-linux-x86_64.exe -O /protoc-gen-grpc-java
RUN chmod +x /protoc-gen-grpc-java

# FINAL IMAGE
# GOTCHA: Don't use Alpine cause of incompatibity with `grpc_node_plugin` binary
FROM ubuntu:latest

ARG DST=/usr/local/bin
ARG GOOGLEAPIS_PATH=/googleapis

# Protoc
COPY --from=node-builder /dist/protoc ${DST}/protoc

# Plugins
COPY --from=ts-builder /dist/protoc-gen-ts ${DST}/protoc-gen-ts
COPY --from=go-builder /go/bin/protoc-gen-go ${DST}/protoc-gen-go
COPY --from=go-builder /go/bin/protoc-gen-doc ${DST}/protoc-gen-doc
COPY --from=web-builder /protoc-gen-grpc-web ${DST}/protoc-gen-grpc-web
COPY --from=node-builder /dist/grpc_node_plugin ${DST}/protoc-gen-grpc
COPY --from=java-builder /protoc-gen-grpc-java ${DST}/protoc-gen-grpc-java

WORKDIR /src

CMD ["/usr/local/bin/protoc", "--help"]