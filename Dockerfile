# Dockerfile
FROM scottyhardy/docker-wine:latest

# Download and install LTspice
RUN wget https://ltspice.analog.com/software/LTspice64.msi && \
    wine msiexec /i LTspice64.msi && \
    rm LTspice64.msi

# Set up an alias for LTspice
RUN echo "alias ltspice='wine /root/.wine/drive_c/Program\ Files/ADI/LTspice/LTspice.exe\'" >> ~/.bashrc

# Set bash as the entry point
ENTRYPOINT ["/bin/bash", "-l", "-c"]
