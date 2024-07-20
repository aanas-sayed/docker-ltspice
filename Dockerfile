# Use the base image with Wine
FROM scottyhardy/docker-wine:latest

# Download and install LTspice
RUN wget https://ltspice.analog.com/software/LTspice64.msi && \
    wine msiexec /i LTspice64.msi && \
    rm LTspice64.msi

# Install Xvfb and other necessary tools
RUN apt-get update && \
    apt-get install -y xvfb libgl1-mesa-dri

# Copy the startup script and ensure it has correct line endings and permissions
COPY xvfb-startup.sh /xvfb-startup.sh
RUN sed -i 's/\r$//' /xvfb-startup.sh && chmod +x /xvfb-startup.sh

# Default resolution and arguments for Xvfb
ARG RESOLUTION="1920x1080x24"
ENV XVFB_RES="${RESOLUTION}"
ARG XARGS=""
ENV XVFB_ARGS="${XARGS}"

# Set the entry point to the startup script
ENTRYPOINT ["/xvfb-startup.sh"]
