# docker-ltspice

<!-- badges: start -->
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

Run [LTspice](https://www.analog.com/en/resources/design-tools-and-calculators/ltspice-simulator.html) headlessly in Docker via Wine. Designed for batch simulation, CI pipelines, and server use—no desktop required.

The image is based on `debian:bookworm-slim` with Wine (stable) and LTspice pre-installed. The entrypoint automatically handles Wine initialisation and starts Xvfb on `:99`, so simulations work out of the box.

Pre-built images are available on [DockerHub](https://hub.docker.com/r/aanas0sayed/docker-ltspice).

> [!IMPORTANT]
> The image is `linux/amd64` only. On ARM machines (e.g. Apple Silicon), add `--platform linux/amd64` to all `docker run` commands.

> [!WARNING]
> **Apple Silicon / 16 KB page hosts:** Wine 10+ aborts with `anon_mmap_fixed: Assertion '!((UINT_PTR)start & host_page_mask)' failed` when run under QEMU user-mode emulation on hosts with a 16 KB page size (Apple Silicon Macs via Docker Desktop, Asahi Linux, etc.). This is a known upstream Wine bug — see [winehq #58084](https://bugs.winehq.org/show_bug.cgi?format=multiple&id=58084) — and is **not yet fixed** in Wine 10 or 11.
>
> **Workaround:** Use the `macos-latest` tag, which is pinned to Wine 9.0 and does not exhibit this bug:
> ```bash
> docker pull --platform linux/amd64 aanas0sayed/docker-ltspice:macos-latest
> ```
> See the [macOS section](#macos-xquartz) below for full usage instructions.
>
> Once upstream ships a fix this workaround will no longer be needed and `macos-latest` can be replaced with `latest`.

---

## Headless usage

Mount a directory containing your netlist and run LTspice in batch mode:

```bash
docker run --rm \
  -v /path/to/netlists:/sim \
  aanas0sayed/docker-ltspice \
  ltspice -b -run "Z:\\sim\\your_circuit.net"
```

The `ltspice` command is a thin wrapper around `wine LTspice.exe`.

### CI example

See [test.sh](test.sh) and [.github/workflows/test.yml](.github/workflows/test.yml) for a working example that runs a simulation and validates `.meas` results from the output log.

---

## X11 forwarding (GUI mode)

### Linux

```bash
docker run --rm -it \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  aanas0sayed/docker-ltspice
```

### macOS (XQuartz)

> [!NOTE]
> Use the `macos-latest` tag on Apple Silicon — see the warning above.

1. Install XQuartz:

    ```bash
    brew install --cask xquartz
    ```

2. Enable TCP listening (XQuartz disables this by default) and restart:

    ```bash
    defaults write org.xquartz.X11 nolisten_tcp -bool false
    killall XQuartz 2>/dev/null; open -a XQuartz
    ```

3. Allow connections from localhost:

    ```bash
    DISPLAY=:0 xhost +127.0.0.1
    ```

4. Run the container:

    ```bash
    docker run --rm -it \
      --platform linux/amd64 \
      -e DISPLAY=host.docker.internal:0 \
      -v /tmp/.X11-unix:/tmp/.X11-unix \
      aanas0sayed/docker-ltspice:macos-latest
    ```

> [!NOTE]
> **First-run Xvfb failure:** On the first `docker run`, Xvfb may fail to start (`ERROR: Xvfb exited unexpectedly`). This is a known issue on macOS. Simply run `ltspice` from the shell prompt and it will work — the container is still usable after the entrypoint error. This only occurs with X11 forwarding.

---

## Troubleshooting

- **Xvfb fails on first run (macOS):** The entrypoint prints `ERROR: Xvfb exited unexpectedly` on the first container start on macOS. This is a known issue — the container is still usable. Run `ltspice` from the shell and it will work normally.
- **File not found / path errors:** LTspice runs inside Wine, so paths must use the Wine `Z:` drive (which maps to `/` on the container). For example, a netlist mounted at `/sim/circuit.net` should be passed as `Z:\\sim\\circuit.net`.
- **Interactive shell:** The entrypoint still runs (priming Wine and starting Xvfb) before handing off to your command:

    ```bash
    docker run --rm -it aanas0sayed/docker-ltspice /bin/bash
    ```

---

## Contributing

Issues and pull requests are welcome.

## License

[MIT License](https://opensource.org/license/MIT) — see [LICENSE](LICENSE) for details.
