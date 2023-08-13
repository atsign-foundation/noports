#!/usr/bin/env python3
import argparse
from time import sleep

from lib import SSHNPDClient

def main():
    parser = argparse.ArgumentParser("sshnpd")
    parser.add_argument("-m", "--manager", dest="manager_atsign", type=str, help="Client Atsign (sshnp's atsign)")
    parser.add_argument("-a", "--atsign", dest="atsign", type=str, help="Device Atsign (sshnpd's atsign)")
    parser.add_argument("-d", "--device", dest="device", type=str, help="Device Name")
    parser.add_argument("-u", "--username", dest="username", type=str, help="Username", default="default")
    parser.add_argument("-v", action='store_true', dest="verbose", help="Verbose")
    
    args = parser.parse_args()

    sshnpd = SSHNPDClient(args.atsign, args.manager_atsign, args.device, args.username, args.verbose)
    
    try:
        sshnpd.start()
        while len(SSHNPDClient.threads) > 0:
            sleep(1)
        
            
    except Exception as e:
        print(e)


if __name__ == "__main__":
    main()
