# BeBe: Bleeding Edge Build Environment


## Build steps

1. Clone project
   ```
   git clone https://github.com/twon/bebe.git bebe
   cd bebe
   ```

2. Install Conan
   ```
   python3 -m venv .venv         # Create a Python virtual env
   source ./.venv/bin/activate   # Activate the virtual env
   pip install conan             # Install conan
   ```
## Docker Set Up

### For Mac OS

https://apple.stackexchange.com/questions/373888/how-do-i-start-the-docker-daemon-on-macos

If you hit the following error when creating the docker machine then follow ensure the /tmp directory is writable by following the advice here : https://superuser.com/a/1136881
```
Failed to open a session for the virtual machine ubuntu.

The virtual machine 'ubuntu' has terminated unexpectedly during startup with exit code 1 (0x1).

Result Code: NS_ERROR_FAILURE (0x80004005)
Component: MachineWrap
Interface: IMachine {85cd948e-a71f-4289-281e-0ca7ad48cd89}
```

If you hit the following error when creating the docker machine then follow the advice here to create the /etc/vbox/network.confs file: https://stackoverflow.com/a/69745931/4764531
```
There was an error while executing `VBoxManage`, a CLI used by Vagrant
for controlling VirtualBox. The command and stderr is shown below.

Command: ["hostonlyif", "ipconfig", "vboxnet0", "--ip", "192.168.33.1", "--netmask", "255.255.255.0"]

Stderr: VBoxManage: error: Code E_ACCESSDENIED (0x80070005) - Access denied (extended info not available)
VBoxManage: error: Context: "EnableStaticIPConfig(Bstr(pszIp).raw(), Bstr(pszNetmask).raw())" at line 242 of file VBoxManageHostonly.cpp
```

