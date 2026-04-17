FROM scottyhardy/docker-wine:latest

# Download and install LTspice
RUN wget https://ltspice.analog.com/software/LTspice64.msi && \
    wine msiexec /i LTspice64.msi && \
    rm LTspice64.msi

# Install a wrapper script so 'ltspice' works in any shell
RUN printf '#!/bin/sh\nexec wine "/root/.wine/drive_c/Program Files/ADI/LTspice/LTspice.exe" "$@"\n' \
    > /usr/local/bin/ltspice && chmod +x /usr/local/bin/ltspice

# Set bash as the entry point
ENTRYPOINT ["/bin/bash"]
