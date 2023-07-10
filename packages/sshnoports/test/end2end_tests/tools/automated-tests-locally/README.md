# How to run this automated end-to-end tests locally

## Prerequisites

- [Git](https://git-scm.com/downloads)
- [Docker Desktop](https://docs.docker.com/get-docker/) which already contains [Docker Compose](https://docs.docker.com/compose/install/)
- [3 atSigns](my.atsign.com/go) and their [.atKeys files](https://www.youtube.com/watch?v=tDqrLKSKes8)

## Running the Tests

You can either set up everything [manually](#manually) or use the [shell script](#with-the-shell-script) to which sets up and runs everything for you manually.

### With the Shell Script

Everything you need to do to set up the automated tests [manually](#manually) are done for you with the shell script.

1. Clone the repository

```sh
git clone https://github.com/atsign-foundation/sshnoports.git
```

2. Change directory into `automated-tests-locally`

```sh
cd test/end2end_tests/tools/automated-tests-locally
```

3. Run the `run-local.sh` script

```sh
./run-local.sh -1 @sshnp -2 @sshnpd -3 @sshrvd -t trunk-local-release -d e2e
```

4. Output should be similar to:

```sh
jeremytubongbanua@Jeremys-M2-Air automated-tests-locally % sh run-local.sh -1 @jeremy_0 -2 @smoothalligator -3 @rv_am -t local-local-local -d e2e 
Running: cd ../../tests/local-local-local
Running: sudo docker-compose build
Running: sudo docker-compose up --exit-code-from=container-sshnp
Running: sudo docker-compose down
[+] Building 0.5s (2/4)
...
sshnp   | 
sshnp   | INFO|2023-07-10 22:08:59.634812| sshnp |Received f3ad42ef-1381-4fc7-9db0-736e74572e67 notification 
sshnp   | 
sshnp   | INFO|2023-07-10 22:08:59.634852| sshnp |Session f3ad42ef-1381-4fc7-9db0-736e74572e67 connected successfully 
sshnp   | 
sshnp   | INFO|2023-07-10 22:08:59.681895| sshnp |Tidying up files 
sshnp   | 
sshnp   | ssh -p 36019 atsign@localhost -i /atsign/.ssh/id_ed25519 
sshnp   | Pseudo-terminal will not be allocated because stdin is not a terminal.
sshnpd  | INFO|2023-07-10 22:09:00.051135| sshnpd |SUCCESS:id: 0493b2c4-e3ac-4321-948a-e3a740ab0eec status: NotificationStatusEnum.delivered for: f3ad42ef-1381-4fc7-9db0-736e74572e67 
sshnpd  | 
sshnp   | Warning: Permanently added '[localhost]:36019' (ED25519) to the list of known hosts.
sshnp   | Linux 0b16ad512b48 5.15.49-linuxkit #1 SMP PREEMPT Tue Sep 13 07:51:32 UTC 2022 aarch64
sshnp   | 
sshnp   | The programs included with the Debian GNU/Linux system are free software;
sshnp   | the exact distribution terms for each program are described in the
sshnp   | individual files in /usr/share/doc/*/copyright.
sshnp   | 
sshnp   | Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
sshnp   | permitted by applicable law.
sshnp   | Test Passed
sshnp   | Successfully SSH'd into the sshnpd container
```

### Manually

1. Clone this repository

```sh
git clone https://github.com/atsign-foundation/sshnoports.git
```

2. Add your keys to the contexts.

Your file structure should be similar to: `contexts/sshnp/keys/@alice_key.atKeys`, `contexts/sshnpd/keys/@bob_key.atKeys`, and `contexts/sshrvd/keys/@charlie_key.atKeys`. sshrvd keys are optional if you are using the @rv_am, @rv_eu, or @rv_ap rv's.

3. Copy the entrypoints to their corresponding contexts using `cp` or by simply copying and pasting the files.

- templates/sshnp_entrypoint.sh -> contexts/sshnp/entrypoint.sh
- templates/sshnpd_entrypoint.sh -> contexts/sshnpd/entrypoint.sh
- templates/sshrvd_entrypoint.sh -> contexts/sshrvd/entrypoint.sh

4. Edit each `entrypoint.sh` with the correct atSigns and the device name you want to use. For example, my `contexts/sshnp/entrypoint.sh` file looks like:

```sh
#!/bin/bash
sleep 2 # time for sshnpd to share device name
~/.local/bin/sshnp -f @jeremy_0 -t @smoothalligator -d e2e -h @rv_am -s id_ed25519.pub -v > logs.txt
cat logs.txt
tail -n 5 logs.txt | grep "ssh -p" > sshcommand.txt

# if sshcommand.txt is empty, exit 1
if [ ! -s sshcommand.txt ]
then
    echo "sshcommand.txt is empty"
    tail -n 1 logs.txt || echo
    exit 1
fi

echo " -o StrictHostKeyChecking=no " >> sshcommand.txt ;
echo "sh test.sh " | $(cat sshcommand.txt)
sleep 2 # time for ssh connection to properly exit
```

5. Change directory into the type of test you want to test. Example: you want to test your local environment's sshnp against the trunk sshnpd and the release sshrvd. You would change directory into `tests/local-trunk-release`.

```sh
cd <sshnp-test>-<sshnpd-test>-<sshrvd-test>
sudo docker compose build
sudo docker compose up --exit-code-from=container-sshnp
sudo docker compose down
```

## Troubleshooting and Tips

- If you get 'permission denied' error when trying to run the scripts, you may need to do something similar to: `chmod -R 777 ./configuration/`
- If you get a 'load metadata for docker.io/...' error when trying to build the docker images, you can try running `rm ~/.docker/config.json` and then try again.
- (minor optimization): If you are using one of the following rv's: @rv_am, @rv_eu, or @rv_ap, then the third container that you specify (release, local, trunk) will be irrelevant, and you will be better off picking a image that was already built (e.g., you run a local-trunk-local test instead of a local-trunk-release so that you can using/building the release image)
- If you want to rebuild an image (e.g., you want to rebuild the trunk image because a new trunk commit was recently pushed), you can pass in the `--no-cache` flag into the `run-local.sh` script to rebuild the images without using cache.