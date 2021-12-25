# protocore

[![docker][docker-img]][docker]

[docker]: https://hub.docker.com/r/teryaew/protocore
[docker-img]: https://img.shields.io/docker/v/teryaew/protocore

Protobuf compiler image with built-in plugins.

Inspired by https://github.com/openlawteam/protocore

---

## Build

`docker build --tag teryaew/protocore:0.0.1 .`

## Push

```
docker login
docker push teryaew/protocore:0.0.1
```

## Java

List of pre-built binaries:

https://repo1.maven.org/maven2/io/grpc/protoc-gen-grpc-java/
