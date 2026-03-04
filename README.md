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

The connection to the IHC controller can be configured using the following environment variables:

* **IHC_IP**: The IP address of the controller
* **IHC_USERNAME**: IHC username
* **IHC_PASSWORD**: IHC User password


Running a container using the environment variables:

```
docker run -d --name ihc-captain \
  -p 8080:80 -p 8443:443 \
  -v /path/on/host:/app/data \
  -e IHC_IP="192.168.1.xxx" \
  -e IHC_USERNAME="admin" \
  -e IHC_PASSWORD="password" \
  zimagedk/ihccaptain:latest
```
