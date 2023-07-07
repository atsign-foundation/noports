#!/bin/bash
sudo docker compose build --build-arg branch=trunk --no-cache
sudo docker compose up --abort-on-container-exit --exit-code-from=container-trunk-sshnp
sudo docker compose down