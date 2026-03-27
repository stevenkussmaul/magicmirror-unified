#!/bin/bash
exec python3 -m gunicorn -k gevent -b 0.0.0.0:7891 mmpm.wsgi:app
