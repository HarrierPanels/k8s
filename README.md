## EC2 User Data script:
```
#!/bin/bash

export EXTERNAL_NAME=$(curl -s checkip.amazonaws.com)
curl -s https://raw.githubusercontent.com/HarrierPanels/k8s/main/deploy.sh | bash
```
