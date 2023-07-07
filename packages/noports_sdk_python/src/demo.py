from sshnpd_manager import SSHNPDManager

manager = SSHNPDManager("@xavierchanth", "@rv_am", "@xchan", device_name="playpen")

out, err = manager.run("ls -l")

print(out)

manager.close()
