# Container HEALTHCHECK: the engine is healthy when its HTTP API answers.
try {
    [void](Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Uri "http://127.0.0.1:$($env:MTAT_PORT)/api/ping")
    exit 0
} catch {
    exit 1
}
