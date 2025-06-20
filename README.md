# MacRMM-Script

This script is designed to assist users in adding Mac agents to Tactical RMM without the need for upfront payment for code-signed agents. If you find this solution beneficial, please consider contributing to the Tactical RMM project!

> This script had a complete rewrite and now only supports MacOS 14 (Sonoma) and above.

# rmmagent-script

Script for one-line installation and updating of the tacticalRMM agent.

> Currently, both amd64 and arm64 scripts are available and has been tested with MacOS 14 (Sonoma) and MacOS 15 (Sequoia); however, only the amd64 version has been tested on macOS 13 (Ventura).

Scripts for additional platforms will be developed and released as they are adapted. You are welcome to modify the script and contribute your improvements back to the project.

# Usage

Download the script that match your configuration

## Install
To install agent launch the script with this argument:

```bash
./rmmagent-mac.sh install 'API URL' 'Client ID' 'Site ID' 'Auth Key' 'Agent Type'
```
The compiling can be quite long, don't panic and wait few minutes... USE THE 'SINGLE QUOTES' IN ALL FIELDS!

The argument are:

2. API URL

  Your api URL for agent communication usually https://api.fqdn.com.
  
5. Client ID

  The ID of the client in which agent will be added.
  Can be view by hovering the name of the client in the dashboard.
  
6. Site ID

  The ID of the site in which agent will be added.
  Can be view by hovering the name of the site in the dashboard.
  
7. Auth Key

  Authentication key given by dashboard by going to dashboard > Agents > Install agent (Windows) > Select manual and show
  Copy **ONLY** the key after *--auth*.
  
8. Agent Type

  Can be *server* or *workstation* and define the type of agent.
  
### Example
```bash
./rmmagent-mac.sh install "https://api.fqdn.com" 3 1 "XXXXX" server
```

## Update
Simply launch the script that match your system with *update* as argument.

```bash
./rmmagent-mac.sh update
```
## Enable Permissions
This sets up all the permissions for screenrecording, file, and disk access for the meshagent.

```bash
./rmmagent-mac.sh enablepermissions
```
## Seqouia Fix
This will fix issues with "Take Control" from the dashboard not displaying the screen. Credit goes to [PeetMcK](https://github.com/PeetMcK) and [si458](https://github.com/si458) for the solution [https://github.com/Ylianst/MeshCentral/issues/6402](https://github.com/Ylianst/MeshCentral/issues/6402)
```bash
./rmmagent-mac.sh sequoiafix
```

## Uninstall
To uninstall the agent, execute the script with the following argument:

```bash
./rmmagent-mac.sh uninstall
```

### WARNING
- You should **only** attempt this if the agent removal feature on TacticalRMM is not working.
- Running uninstall will **not** remove the connections from the TacticalRMM and MeshCentral Dashboard. You will need to manually remove them. It only forcefully removes the agents from your linux box.
