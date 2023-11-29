## EC2 User Data script 
#### For systems with higher specifications (2 Cores, 2 GiB RAM, and above)
```
#!/bin/bash

# PlayPit deployment
export EXTERNAL_NAME=$(curl -s checkip.amazonaws.com)
curl -s https://raw.githubusercontent.com/HarrierPanels/k8s/main/deploy.sh | bash
```
#### For systems with lower specifications (1 Core, 1 GiB RAM, such as AWS Free Tier t2.micro)
```
#!/bin/bash

# t2.micro setup
# Swap 4 Gb
dd if=/dev/zero of=/swapfile bs=128M count=32
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
swapon -s
echo '/swapfile swap swap defaults 0 0' | tee -a /etc/fstab

# PlayPit deployment
export EXTERNAL_NAME=$(curl -s checkip.amazonaws.com)
curl -s https://raw.githubusercontent.com/HarrierPanels/k8s/main/deploy.sh | bash
```
