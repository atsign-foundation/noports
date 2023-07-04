#!/bin/bash
sudo docker-compose up $@ --exit-code-from=sshnp-trunk
# sudo docker-compose down