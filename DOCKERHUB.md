# IHC Captain Container Images

These images wraps the IHC Captain application by [Mikkel Skovgaard](https://jemi.dk/ihc/).

A big thanks to Mikkel for picking up after Schneider dropped the ball on all us who have based the lighting of our house on IHC.

## Image tags
All images are tagged during build, with the version of IHC Captain included. Tags set: `latest`, `major`, `major.minor`, `major.minor.patch`, `major-minor-patch-timestamp`. All tags, but the last, may be moved on next update

Example:
Version 2.0.1-20260101-0845 get the following tags:
* `latest` (latest image)
* `2` (latest build in the 2 series)
* `2.0` (latest build in the 2.0 series)
* `2.0.1`
* `2.0.1-20260101-0845`

# Running Containers

Running a container with data mounted to a path on the host, and ports mapped to unprivileged ports on the host.

```
docker run -d --name ihc-captain -v /path/on/host:/app/data -p8080:80 -p8443:443 zimagedk/ihccaptain:latest
```
# Controller Configuration

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
