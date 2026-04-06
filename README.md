# Container Image for IHC Captain

A big thanks to [IHC Captain](https://jemi.dk/ihc/) for picking up after Schneider dropped the ball on all us who have based the lighting of our house on IHC.

This project builds both a x86 and an ARM 64 bit image by fetching the binaries from the IHC Captain update site, if there is an update available. The images will be deployed as a single multi-arch manifest: [IHC Captain @ Docker Hub](https://hub.docker.com/r/zimagedk/ihccaptain)


## Build Requirements

Install qemu binfmt support, to support cross-platform build

For debian-based systems, run:

```
sudo apt-get install qemu-user-static binfmt-support
```


## Building

Run `build.sh` display a help text, showing how to build the images. 

## Running

Running a container with data mounted to a path on the host, and ports mapped to unprivileged ports on the host.

```
docker run -d --name ihc-captain -v /path/on/host:/app/data -p8080:80 -p8443:443 zimagedk/ihccaptain:latest
```

See [IHC Captain Installation Guide for Docker](https://jemi.dk/ihc/beta/install-guide.html#docker) for configuration details.
