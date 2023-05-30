# docker-ltspice

This Docker image provides an environment for running LTspice, a popular electronic circuit simulation software, using Wine. It is based on the scottyhardy/docker-wine project and includes additional configurations specific to running LTspice.

## Usage

To use the aanas0sayed/docker-ltspice Docker image, you can follow these steps:

1. Pull the latest version of the image from Docker Hub:

    ```
    docker pull aanas0sayed/docker-ltspice
    ```

2. Start the Docker container:

    ```
    docker run -it --rm -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix aanas0sayed/docker-ltspice
    ```
    This command will start the container in interactive mode, forwarding the X11 display to the host machine. This allows LTspice to display its graphical interface on your local machine.

3. Inside the container, you can run LTspice by executing the ltspice command:

    ```
    ltspice
    ```
    
    This will start LTspice and you can use it as you would on a regular desktop environment.

## Running as the current user

By default, the Docker container runs as the root user. However, you can start the container as yourself by passing the --user option with your user ID (UID) and group ID (GID) to the docker run command. This is especially useful when binding to the local file system:

```
docker run -it --rm -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix --user=$(id -u):$(id -g) aanas0sayed/docker-ltspice
```

This command runs the container with the same username, UID, GID, and home path as your current user, allowing you to interact with files on the local file system without permissions issues.

## Additional Options

You can use additional options to customize the behavior of the container. Here are some examples:

- To run LTspice as root with RDP server enabled:

    ```
    docker run -it --rm -e RDP_SERVER=yes -p 3389:3389 aanas0sayed/docker-ltspice
    ```

- To run LTspice as the current user with RDP server enabled:

    ```
    docker run -it --rm -e RDP_SERVER=yes -p 3389:3389 -e USER_ID=$(id -u) -e GROUP_ID=$(id -g) aanas0sayed/docker-ltspice
    ```
    
    For more options and detailed usage instructions, refer to the scottyhardy/docker-wine project's README file: https://github.com/scottyhardy/docker-wine/blob/master/README.md

## Troubleshooting

If you encounter any issues while running LTspice in the Docker container, you can try the following troubleshooting steps:

- Test the display by running Notepad:

    ```
    ltspice wine notepad
    ```

- Test the sound by using pacat:

    ```
    ltspice pacat -vv /dev/urandom
    ```

These commands will help verify that the display and sound configurations are working correctly within the container.

## Contributing

If you find any issues with the aanas0sayed/docker-ltspice Docker image or have suggestions for improvements, please feel free to contribute by creating a GitHub issue or submitting a pull request. Your contributions are welcome!

## License

This project is licensed under the MIT License. For more details, please refer to the LICENSE file.

This README file is an adaptation of the original scottyhardy/docker-wine project's README file, incorporating information specific to the aanas0sayed/docker-ltspice project. For more information on the scottyhardy/docker-wine project, please visit https://github.com/scottyhardy/docker-wine.