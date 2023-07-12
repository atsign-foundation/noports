#!/bin/bash
cd branch ; sudo docker compose down --rmi=local --remove-orphans ; cd ..
cd release ; sudo docker compose down --rmi=local --remove-orphans ; cd ..
cd local ; sudo docker compose down --rmi=local --remove-orphans ; cd ..
cd blank ; sudo docker compose down --rmi=local --remove-orphans ; cd ..
