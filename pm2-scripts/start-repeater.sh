#!/bin/bash
exec python3 -m gunicorn -k geventwebsocket.gunicorn.workers.GeventWebSocketWorker -w 1 'mmpm.api.repeater:create()' -b 0.0.0.0:8907
