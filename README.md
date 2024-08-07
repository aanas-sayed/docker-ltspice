# docker-ltspice

<!-- badges: start -->

[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

<!-- badges: end -->

This Docker image provides an environment for running [LTspice](https://www.analog.com/en/resources/design-tools-and-calculators/ltspice-simulator.html), a popular electronic circuit simulation software, using Wine on a Linux image. It is based on the scottyhardy/docker-wine project and includes additional configurations specific to running LTspice.

`aanas0sayed/docker-ltspice` is aimed for running LTspice for bulk simulations as part of pipelines. Headless operations will require Xvfb to be set up correctly. This is currently in the pipeline.

## Pre-built images

Images are available on [DockerHub](https://hub.docker.com/r/aanas0sayed/docker-ltspice).

## Usage

### Pull the Image

```bash
docker pull aanas0sayed/docker-ltspice
```

### Running the Container

> [!IMPORTANT]
>
> The base image is `linux/amd64` and will not work on a machine running with a `arm64` architecture unless `--platform linux/amd64` is added to the `docker run` command.

#### Running on Linux/Windows

```bash
docker run -it --rm -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix aanas0sayed/docker-ltspice
```

#### Running on Mac

1. Install [XQuartz](https://www.xquartz.org):

    ```bash
    brew install --cask xquartz
    ```

2. Logout and login of your Mac to activate XQuartz as the default X11 server.

3. Start [XQuartz](https://www.xquartz.org):

    ```bash
    open -a XQuartz
    ```

4. Enable "Allow connections from network clients" in Security Settings.
5. Restart your Mac and start XQuartz again:

    ```bash
    open -a XQuartz
    ```

> [!NOTE]
>
> If connecting to a remote server, the access control will need to be modified. Running `xhost +` allows any client to connect (not recommended). If you have security concerns you can append an IP address for a whitelist mechanism. Alternatively, if you want to limit X11 forwarding to local containers, you can limit clients to localhost only via `xhost +localhost`
> This is not a persistent setting.

6. Run the container:

    ```bash
    docker run -it --rm -e DISPLAY=docker.for.mac.host.internal:0 -v /tmp/.X11-unix:/tmp/.X11-unix aanas0sayed/docker-ltspice
    ```

For MacBook M series (ARM chip), add `--platform linux/amd64` to the command.

For support on this topic, please check the guide on [X11 forwarding on macOS and docker](https://gist.github.com/sorny/969fe55d85c9b0035b0109a31cbcb088) 

### Running as Current User

```bash
docker run -it --rm -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix --user=$(id -u):$(id -g) aanas0sayed/docker-ltspice
```

This command runs the container with the same username, UID, GID, and home path as your current user, allowing you to interact with files on the local file system without permissions issues.

## Additional Options

- Run with RDP server enabled (as root):

    ```bash
    docker run -it --rm -e RDP_SERVER=yes -p 3389:3389 aanas0sayed/docker-ltspice
    ```

- Run with RDP server enabled (as current user):

    ```bash
    docker run -it --rm -e RDP_SERVER=yes -p 3389:3389 -e USER_ID=$(id -u) -e GROUP_ID=$(id -g) aanas0sayed/docker-ltspice
    ```

For more options and detailed usage instructions on the base image, refer to the [scottyhardy/docker-wine](https://github.com/scottyhardy/docker-wine/blob/master/).

## Troubleshooting

- Test the display:

    ```bash
    ltspice wine notepad
    ```

- Test the sound:

    ```bash
    ltspice pacat -vv /dev/urandom
    ```

## Contributing

If you find any issues or have suggestions for improvements, please contribute by creating a GitHub issue or submitting a pull request.

## License

This project is licensed under the [MIT License](https://opensource.org/license/MIT). For more details, please refer to the LICENSE file.
