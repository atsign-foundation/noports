#!/bin/bash
sudo docker compose build --no-cache
sudo docker compose up --abort-on-container-exit --exit-code-from=container-sshnp
sudo docker compose down