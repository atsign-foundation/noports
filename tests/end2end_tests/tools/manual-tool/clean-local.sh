#!/bin/bash
sudo docker compose --project-directory branch down --rmi=local --remove-orphans
sudo docker compose --project-directory release down --rmi=local --remove-orphans
sudo docker compose --project-directory local down --rmi=local --remove-orphans
sudo docker compose --project-directory blank down --rmi=local --remove-orphans
