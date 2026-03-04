# Container Image for IHC Captain

A big thanks to [IHC Captain](https://jemi.dk/ihc/) for picking up after Schneider dropped the ball on all us who have based the lighting of our house on IHC.

## Building

The `build.sh` handles either
* fetching the binary archive and building the container image using buildah
* or building using a manually downloaded archive

## Running

Running a container with data mounted to a path on the host, and ports mapped to unprivileged ports on the host.

```
docker run -d --name ihc-captain -v /path/on/host:/app/data -p8080:80 -p8443:443 zimagedk/ihccaptain:latest
```

See [IHC Captain Installation Guide for Docker](https://jemi.dk/ihc/beta/install-guide.html#docker) for configuration details.
