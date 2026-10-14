# MTAT engine -- headless container image (PowerShell 7 + VMware PowerCLI on Linux).
# Build from the repository root:  docker compose build   (or see docker/README.md)

ARG PWSH_IMAGE=mcr.microsoft.com/powershell:7.4-ubuntu-22.04
FROM ${PWSH_IMAGE}

# Pinned for reproducible builds; bump deliberately. The VMware.PowerCLI meta-module is installed
# (not just VMware.VimAutomation.Core) because its manifest pins every sub-module to an exact
# version; installing Core alone let its dependencies float to newer, incompatible releases (#30).
ARG POWERCLI_VERSION=13.3.0.24145081
# Set to 1 only for offline smoke tests of the container itself (see docker/README.md).
ARG SKIP_POWERCLI=0

ENV TERM=dumb \
    POWERSHELL_TELEMETRY_OPTOUT=1 \
    POWERSHELL_UPDATECHECK=Off \
    MTAT_HEADLESS=1 \
    MTAT_PORT=8600 \
    MTAT_BIND_HOST=+

# Optional corporate root CAs (e.g. a TLS-inspecting proxy in front of PSGallery or vCenter):
# drop *.crt files into docker/certs/ before building. An empty folder is a no-op.
COPY docker/certs/ /usr/local/share/ca-certificates/mtat/
# ca-certificates already ships in the base image; tzdata does not, and without it the TZ
# variable (docker-compose.yml) is silently ignored and every log timestamp is UTC.
RUN update-ca-certificates \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata \
 && rm -rf /var/lib/apt/lists/*

COPY docker/verify-powercli.ps1 /opt/mtat-build/verify-powercli.ps1
RUN if [ "$SKIP_POWERCLI" != "1" ]; then \
      pwsh -NoLogo -NoProfile -Command " \
        \$ErrorActionPreference = 'Stop'; \
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; \
        Install-Module -Name VMware.PowerCLI -RequiredVersion $POWERCLI_VERSION -Scope AllUsers -Force -AllowClobber; \
        Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP \$false -Confirm:\$false | Out-Null" \
   && pwsh -NoLogo -NoProfile -File /opt/mtat-build/verify-powercli.ps1 -ExpectedPowerCliVersion $POWERCLI_VERSION ; \
    fi

RUN useradd --create-home --uid 10001 mtat \
 && mkdir -p /opt/mtat /var/lib/mtat \
 && chown mtat:mtat /var/lib/mtat

# Debug log (MTAT_debug_log.txt) goes to the persisted volume.
ENV MTAT_DATA_DIR=/var/lib/mtat

COPY --chown=mtat:mtat MTAT_v3_1.ps1 /opt/mtat/MTAT.ps1
COPY --chown=mtat:mtat docker/healthcheck.ps1 /opt/mtat/healthcheck.ps1

USER mtat
WORKDIR /opt/mtat
VOLUME ["/var/lib/mtat"]
EXPOSE 8600

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD ["pwsh", "-NoLogo", "-NoProfile", "-File", "/opt/mtat/healthcheck.ps1"]

ENTRYPOINT ["pwsh", "-NoLogo", "-NoProfile", "-File", "/opt/mtat/MTAT.ps1"]
