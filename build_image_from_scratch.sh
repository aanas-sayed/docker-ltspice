#!/bin/bash

# Set the version tags
ubuntu_version="22.04"
ltspice_version="17.1.8"
image_version="0.2"
image_tag="ubuntu-${ubuntu_version}-ltspice-${ltspice_version}-${image_version}"

# Additional tags
latest_image_tag="ubuntu-${ubuntu_version}-latest"

# Step 1: Create the Docker container
# sudo docker create -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix  --name ltspice_container ubuntu:${ubuntu_version} tail -f /dev/null

# Step 2: Start the Docker container
# sudo docker start ltspice_container
sudo docker run -d -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix  --name ltspice_container ubuntu:${ubuntu_version} tail -f /dev/null


# Step 3: Install prerequisites inside the container
sudo docker exec -it ltspice_container /bin/bash -c "
    dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y wget xvfb && \
    mkdir -pm 755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    case \"$ubuntu_version\" in
        \"23.04\")
            wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/lunar/winehq-lunar.sources
            ;;
        \"22.10\")
            wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/kinetic/winehq-kinetic.sources
            ;;
        \"22.04\"|\"20.04\")
            wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources
            ;;
        *)
            echo \"Unsupported Ubuntu version!\"
            exit 1
            ;;
    esac && \
    apt-get update && \
    apt-get install -y --install-recommends winehq-stable && \
    wget https://ltspice.analog.com/software/LTspice64.msi && \
    wine msiexec /i LTspice64.msi && \
    rm LTspice64.msi && \
    apt remove -y wget && \
    apt autoremove -y && \
    echo \"alias ltspice='wine /root/.wine/drive_c/Program\ Files/ADI/LTspice/Ltspice.exe'\" >> ~/.bashrc && \
    source ~/.bashrc && \
    Xvfb :1 -screen 0 1024x768x16 & # Start Xvfb
    export DISPLAY=:1 && # Set the display environment variable
    ltspice
" 

# Step 4: Commit the Docker container to an image with the version tag
sudo docker commit ltspice_container aanas0sayed/ltspice:${image_tag}

# Step 5: Stop and remove the container
sudo docker stop ltspice_container
sudo docker rm ltspice_container

# Step 6: Push the Docker image with
