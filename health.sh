#!/bin/bash
# Healthcheck: verify MagicMirror and MMPM API are responding
curl -sf http://localhost:8080 > /dev/null || exit 1
curl -sf http://localhost:7891 > /dev/null || exit 1
