# sshnp_webserver_demo

## Usage


First do the one-time setup steps:
1. populate `.env` based on `.env.template`
2. run `./setup.sh` to build the demo docker image locally
3. run `docker compose up -d` to start the docker image

### Browser demo
1. run `$(./client.sh)` to start the local webserver
2. Go to [localhost:8080](http://localhost:8080) in your browser
3. Done!

### Mobile demo
1. run the Flutter application
