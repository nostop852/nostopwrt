### openwrt_custom_build.sh
---
**Notice:**
Please log in to the system as a normal user，non-root.

This is an automated configuration script that uses openwrt official source code and third-party apps to build openwrt firmware.
1. The source code of openwrt is the official 23.05.4 stable branch. You can modify the script and use other branches.
2. All apps in this project are public repositories in github, some gadgets you may use. Only the display appearance or the position of some apps in the menu have been modified.
3. Modify the problem that some apps will cause running failures after startup, such as dockerman-- "Cannot connect to the Docker daemon ... " , etc., which have not been tested. Please comment out this part of the code in a non-trial environment.
4. After successfully running the script, the system will automatically open the compilation configuration, select the configuration, save and exit. then execute the "make" command to get your firmware.
5. Workflow:
```shell
chmod +x openwrt_custom_build.sh
./openwrt_custom_build.sh
```
Final work:
```shell
cd ~openwrt
make
```
