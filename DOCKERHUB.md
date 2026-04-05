# IHC Captain Container Images

These images wraps the IHC Captain application by [Mikkel Skovgaard](https://jemi.dk/ihc/).

A big thanks to Mikkel for picking up after Schneider dropped the ball on all us who have based the lighting of our houses on IHC.

## Image tags
All images are tagged during build, with the version of IHC Captain included.
Tags set: `latest`, `major`, `major.minor`, `major.minor.patch`.
All tags, but the last, may be moved on next update

Example:
Version 2.0.1 get the following tags:
| Version | Description |
| - | - |
| `latest` | latest image |
| `2` | latest build in the 2 series |
| `2.0` | latest build in the 2.x series |
| `2.0.1` | the exact version |

<br>

# Running a container

Running a container with data mounted to a path on the host, and ports mapped to unprivileged ports on the host.

```
docker run -d --name ihc-captain -v /path/on/host:/app/data -p8080:80 -p8443:443 zimagedk/ihccaptain:latest
```

See [IHC Captain Installation Guide for Docker](https://jemi.dk/ihc/beta/install-guide.html#docker) for information about configuration using environment variables.
