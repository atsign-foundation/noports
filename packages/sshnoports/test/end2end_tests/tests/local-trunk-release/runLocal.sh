#!/bin/bash
sudo docker compose build --build-arg branch=trunk --build-arg release=3.3.0
sudo docker compose up --abort-on-container-exit --exit-code-from=container-sshnp
sudo docker compose down