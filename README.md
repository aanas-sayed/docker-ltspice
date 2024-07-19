# docker-ltspice

This Docker image provides an environment for running LTspice, a popular electronic circuit simulation software, using Wine on a Linux image. It is based on the scottyhardy/docker-wine project and includes additional configurations specific to running LTspice.

`aanas0sayed/docker-ltspice` is aimed for running LTspice in a headless environment which can be beneficial for bulk simulations as part of pipelines. The GUI is also supported for easy debugging.

## Usage

### Pull the Image

```bash
docker pull aanas0sayed/docker-ltspice
```

### Running the Container

#### Interactive Mode on any platform 

```bash
docker run -it --rm aanas0sayed/docker-ltspice
```

> [!NOTE]
>
> The base image is `linux/amd64` and will not work on a machine running with a `arm64` architecture unless `--platform linux/amd64` is added to the `docker run` command.

```bash
docker run -it --rm aanas0sayed/docker-ltspice
```

#### GUI on Linux/Windows

```bash
docker run -it --rm -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix aanas0sayed/docker-ltspice
```

#### GUI on Mac

1. Install XQuartz:

    ```bash
    brew install --cask xquartz
    ```

2. Logout and login of your Mac to activate XQuartz as the default X11 server.

3. Start XQuartz:

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

For more options and detailed usage instructions, refer to the [scottyhardy/docker-wine README](https://github.com/scottyhardy/docker-wine/blob/master/README.md).

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

This project is licensed under the MIT License. For more details, please refer to the LICENSE file.

For more information on the scottyhardy/docker-wine project, please visit [scottyhardy/docker-wine](https://github.com/scottyhardy/docker-wine).
