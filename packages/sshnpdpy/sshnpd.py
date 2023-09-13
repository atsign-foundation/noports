#!/usr/bin/env python3
import argparse
from time import sleep

from lib import SSHNPDClient

def main():
    parser = argparse.ArgumentParser("sshnpd")
    requiredNamed = parser.add_argument_group('required named arguments')
    requiredNamed.add_argument("-m", "--manager", dest="manager_atsign", type=str, help="Client Atsign (sshnp's atsign)", required=True)
    requiredNamed.add_argument("-a", "--atsign", dest="atsign", type=str, help="Device Atsign (sshnpd's atsign)", required=True)
    requiredNamed.add_argument("-d", "--device", dest="device", type=str, help="Device Name", required=True)
    optional = parser.add_argument_group('optional arguments')
    optional.add_argument("-u",  action='store_true', dest="username",  help="Username", default="default")
    optional.add_argument("-v", action='store_true', dest="verbose", help="Verbose")
    
    
    args = parser.parse_args()

    sshnpd = SSHNPDClient(args.atsign, args.manager_atsign, args.device, args.username, args.verbose)
    
    try:
        sshnpd.start()
        while len(SSHNPDClient.threads) > 0:
            if not sshnpd.is_alive():
                sshnpd.join()
            else:
                sleep(10)
        
            
    except Exception as e:
        print(e)


if __name__ == "__main__":
    main()
