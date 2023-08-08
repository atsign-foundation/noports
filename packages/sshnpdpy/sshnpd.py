#!/usr/bin/env python3
import argparse
from time import sleep

from lib import SSHNPDClient

def main():
    parser = argparse.ArgumentParser("sshnpd")
    parser.add_argument("--manager", dest="manager_atsign", type=str)
    parser.add_argument("--atsign", dest="atsign", type=str)
    parser.add_argument("--device", dest="device", type=str)
    parser.add_argument("--username", dest="username", type=str)
    args = parser.parse_args()
    
    if(args.username == None):
        args.username = "default"
    
    
    sshnpd = SSHNPDClient(args.atsign, args.manager_atsign, args.device, args.username)
    
    try:
        sshnpd.start()
        while len(SSHNPDClient.threads) > 0:
            sleep(1)
        
            
    except Exception as e:
        print(e)


if __name__ == "__main__":
    main()
