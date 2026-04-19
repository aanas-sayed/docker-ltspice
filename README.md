# docker-ltspice

<!-- badges: start -->

[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

<!-- badges: end -->


**docker-ltspice** provides a fully headless, automated environment for running [LTspice](https://www.analog.com/en/resources/design-tools-and-calculators/ltspice-simulator.html) (Windows version) under Wine in Linux containers. It is designed for CI pipelines, batch simulation, and server use—no GUI or desktop required.

**Key features:**
- Runs LTspice in true headless mode (no desktop, no VNC, no RDP needed)
- Handles all Wine/Xvfb quirks for you (see below)
- Works out-of-the-box on Linux CI runners (e.g., GitHub Actions)
- Includes a test harness for automated .meas validation

**Known issue:**
- On macOS, running with a real X11 display (e.g., by passing DISPLAY and using XQuartz) is not reliable—Wine/LTspice may hang or fail to start. Headless mode works and is the only supported configuration on macOS. On Linux, running with a real X11 display usually works, but is not the main focus.

## Pre-built images

Images are available on [DockerHub](https://hub.docker.com/r/aanas0sayed/docker-ltspice).


## Usage (Headless/Bulk Simulation)

```bash
docker run --rm -v "$PWD/test:/sim" aanas0sayed/docker-ltspice:latest
```

This will automatically:
- Prime Wine/LTspice (workaround for Wine GUI service hangs)
- Start Xvfb on :99
- Run your simulation in /sim (see test.sh for an example)

**Typical batch/test usage:**

```bash
docker run --rm -v "$PWD/test:/sim" aanas0sayed/docker-ltspice:latest /bin/bash -c '
    wine "/root/.wine/drive_c/Program Files/ADI/LTspice/LTspice.exe" -b -run "Z:\\sim\\your_circuit.net"
'
```

## Overriding Entrypoint (Advanced/GUI)

If you want to run with a real X11 display, you can override the entrypoint and manage Xvfb/DISPLAY yourself:

```bash
docker run --rm -it --entrypoint /bin/bash -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix aanas0sayed/docker-ltspice
# Now start Xvfb or connect to your X server, then run wine LTspice.exe ...
```

**Warning:** On macOS, if you try to use a real X11 display (e.g., by passing DISPLAY and using XQuartz), Wine/LTspice may hang or fail to start. This is a Wine/X11 limitation and not fixable in this image. Headless mode works. On Linux, running with a real X11 display usually works, but is not the main focus.

## CI Example

See [test.sh](test.sh) and [test.yml](.github/workflows/test.yml) for a full CI pipeline example that validates .meas results from a simulation log.

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


## Known Issues

- **macOS/XQuartz:** Headless mode is the only supported configuration. On macOS, running with XQuartz (by passing DISPLAY) is unreliable and may hang or fail to start.
- **ARM/M-series Macs:** Use `--platform linux/amd64` when running on Apple Silicon.

## Troubleshooting

- If your simulation hangs, make sure you are running in headless mode (do not set DISPLAY to a real X server).
- If you want to debug interactively, override the entrypoint and start Xvfb manually as shown above.


## Contributing

Issues and PRs are welcome! Please file bugs or suggestions on GitHub.

## License

This project is licensed under the [MIT License](https://opensource.org/license/MIT). For more details, please refer to the LICENSE file.
