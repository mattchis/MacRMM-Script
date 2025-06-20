#!/bin/sh
if [[ $1 == "" ]]; then
        echo "First argument is empty !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "help" ]]; then
        echo "There is help but more information is available at github.com/mattchis/rmmagent-macos"
        echo ""
        echo "List of INSTALL/UPDATE argument (no argument name):"
        echo "Arg 1: 'install' or 'update'"
        echo "Arg 2: API URL"
        echo "Arg 3: Client ID"
        echo "Arg 4: Site ID"
        echo "Arg 5: Auth Key"
        echo "Arg 6: Agent Type 'server' or 'workstation'"
        echo ""
        echo "List of UNINSTALL argument (no argument name):"
        echo "Arg 1: 'uninstall'"
        echo ""
	echo "List of ENABLEPERMISSIONS argument (no argument name):"
        echo "Arg 1: 'enablepermissions'"
        echo ""
	echo "List of SEQUOIAFIX argument (no argument name):"
        echo "Arg 1: 'SEQUOIAFIX'"
        echo ""
        echo "Only argument 1 is needed for update and sequoiafix"
        echo ""
        exit 0
fi

if [[ $1 != "install" && $1 != "update" && $1 != "uninstall" && $1 != "enablepermissions" && $1 != "sequoiafix" ]]; then
        echo "First argument can only be 'install' or 'update' or 'uninstall' !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "install" && $2 == "" ]]; then
        echo "Argument 2 (API URL) is empty !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "install" && $3 == "" ]]; then
        echo "Argument 3 (Client ID) is empty !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "install" && $4 == "" ]]; then
        echo "Argument 4 (Site ID) is empty !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "install" && $5 == "" ]]; then
        echo "Argument 5 (Auth Key) is empty !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "install" && $6 == "" ]]; then
        echo "Argument 6 (Agent Type) is empty !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "install" && $6 != "server" && $6 != "workstation" ]]; then
        echo "First argument can only be 'server' or 'workstation' !"
        echo "Type help for more information"
        exit 1
fi

## Setting var for easy scription
#system=$2
#mesh_url=$2
rmm_url=$2
rmm_client_id=$3
rmm_site_id=$4
rmm_auth=$5
rmm_agent_type=$6

go_url_amd64="https://go.dev/dl/go1.24.4.darwin-amd64.pkg"
go_url_arm64="https://go.dev/dl/go1.24.4.darwin-arm64.pkg"

function go_install() {
        ## Installing golang
	echo "###########################"
	echo "# Installing/Upgrading Go #"
	echo "###########################"
        case $(uname -m) in
        x86_64)
          sudo curl -L -o /tmp/golang.pkg $go_url_amd64
        ;;
        arm64)
          sudo curl -L -o /tmp/golang.pkg $go_url_arm64
        ;;
        esac
        
        sudo mkdir /usr/local/go
	sudo installer -pkg /tmp/golang.pkg -target /usr/local/go
        sudo rm /tmp/golang.pkg

        source /etc/profile

        echo "Golang Install Done !"
}

function getCSREQBlob(){
	# Sign the app
	sudo codesign --detached /opt/tacticalmesh/meshagent.sig -s - /opt/tacticalmesh/meshagent

	# Get the requirement string from codesign
	req_str=$(sudo codesign -d -r- --detached /opt/tacticalmesh/meshagent.sig /opt/tacticalmesh/meshagent 2>&1 | awk -F ' => ' '/designated/{print $2}')

	# Convert the requirements string into it's binary representation
	# csreq requires the output to be a file so we just throw it in /tmp
	echo "$req_str" | sudo csreq -r- -b /tmp/csreq.bin >/dev/null 2>&1

	# Convert the binary form to hex, and print it nicely for use in sqlite
	req_hex="X'$(sudo xxd -p /tmp/csreq.bin | tr -d '\n')'"

	echo "$req_hex"
    
	# Remove csqeq.bin
	sudo rm -f "/tmp/csreq.bin"
}

function agent_compile() {
        ## Compiling and installing tactical agent from github
	echo "########################"
        echo "# Compiling TRMM Agent #"
	echo "########################"
        sudo curl -L -o /tmp/rmmagent.zip https://github.com/amidaware/rmmagent/archive/refs/heads/master.zip
        sudo unzip /tmp/rmmagent.zip -d /tmp/
        sudo rm /tmp/rmmagent.zip
        case $(uname -m) in
        x86_64)
          sudo /bin/sh -c 'cd /tmp/rmmagent-master && env CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -ldflags "-s -w" -o /tmp/temp_rmmagent'
        ;;
        arm64)
          sudo /bin/sh -c 'cd /tmp/rmmagent-master && env CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -ldflags "-s -w" -o /tmp/temp_rmmagent'
        ;;
        esac
        
        sudo cd /tmp
        sudo rm -Rf /tmp/rmmagent-master
}

function install_agent() {
	echo "#########################"
	echo "# Installing TRMM Agent #"
	echo "#########################"
        sudo cp /tmp/temp_rmmagent /usr/local/bin/rmmagent
        sudo /tmp/temp_rmmagent -m install -meshdir /opt/tacticalmesh -api $rmm_url -client-id $rmm_client_id -site-id $rmm_site_id -agent-type $rmm_agent_type -auth $rmm_auth
        sudo rm /tmp/temp_rmmagent
	sudo xattr -r -d com.apple.quarantine /opt/tacticalmesh/meshagent
}

function update_agent() {
	echo "#######################"
	echo "# Updating TRMM Agent #"
	echo "#######################"
        sudo launchctl bootout system /Library/LaunchDaemons/tacticalagent.plist

        sudo cp /tmp/temp_rmmagent /opt/tacticalagent/tacticalagent
        sudo rm /tmp/temp_rmmagent

        sudo launchctl load -w /Library/LaunchDaemons/tacticalagent.plist
	sudo xattr -r -d com.apple.quarantine /opt/tacticalmesh/meshagent
}

function config_securityandprivacy () {
        # Adding permissions to macOS to allow Accessibility, Screen Capture, and All File Access to the meshagent
	echo "############################################"
        echo "# Applying Security and Privacy Exceptions #"
	echo "############################################"
        req_hex="$(getCSREQBlob)"
	echo "Hex value = $req_hex"
	sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "REPLACE INTO access VALUES('kTCCServiceAccessibility','/opt/tacticalmesh/meshagent',1,2,4,1,$req_hex,NULL,0,'UNUSED',NULL,0,NULL,NULL,NULL,NULL,NULL);"
	sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "REPLACE INTO access VALUES('kTCCServiceScreenCapture','/opt/tacticalmesh/meshagent',1,2,4,1,$req_hex,NULL,0,NULL,NULL,0,NULL,NULL,NULL,NULL,NULL);"
	sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/opt/tacticalmesh/meshagent',1,2,4,1,$req_hex,NULL,0,NULL,NULL,0,NULL,NULL,NULL,NULL,NULL);"
}

function uninstall_agent() {
	echo "###########################"
	echo "# Uninstalling TRMM Agent #"
	echo "###########################"
	if [ -e "/Library/LaunchDaemons/tacticalagent.plist" ]; then
        	sudo launchctl bootout system /Library/LaunchDaemons/tacticalagent.plist
        	sudo rm /Library/LaunchDaemons/tacticalagent.plist
	fi
	if [ -d "/opt/tacticalagent" ]; then
        	sudo rm -Rf /opt/tacticalagent/
	fi
	if [ -e "/etc/tacticalagent" ]; then
        	sudo rm /etc/tacticalagent
	fi
	sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "delete from access where client='/opt/tacticalagent/tacticalagent';"
}

function uninstall_mesh() {
	echo "###########################"
	echo "# Uninstalling Mesh Agent #"
	echo "###########################"
	if [ -e "/Library/LaunchDaemons/meshagent.plist" ]; then
        	sudo launchctl bootout system /Library/LaunchDaemons/meshagent.plist
	fi
	if [ -e "/Library/LaunchAgents/meshagent-agent.plist" ]; then
		sudo rm /Library/LaunchAgents/meshagent-agent.plist
	fi
	if [ -e "/Library/LaunchAgents/meshagent.plist" ]; then
                sudo rm /Library/LaunchAgents/meshagent.plist
        fi
	if [ -e "/opt/tacticalmesh/meshagent" ]; then
        	sudo /opt/tacticalmesh/meshagent -fulluninstall
	fi
	if [ -d "/opt/tacticalmesh" ]; then
        	rm -Rf /opt/tacticalmesh
	fi
        sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "delete from access where client='/opt/tacticalmesh/meshagent';"
}

function sequoia_fix() {
	echo "########################"
	echo "# Applying Sequoia Fix #"
	echo "########################"
	script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	if [ -e "/Library/LaunchAgents/meshagent-agent.plist" ]; then
		sudo rm /Library/LaunchAgents/meshagent-agent.plist
	fi
	if [ -e "/Library/LaunchDaemons/meshagent.plist" ]; then
		sudo rm /Library/LaunchDaemons/meshagent.plist
	fi
	sudo cp "${script_dir}/meshagent.plist" /Library/LaunchAgents/meshagent.plist
	sudo chown root:wheel /Library/LaunchAgents/meshagent.plist
	sudo chmod 666 /opt/tacticalmesh/meshagent.msh
	sudo chmod 666 /opt/tacticalmesh/meshagent.db
}

case $1 in
install)
        go_install
        agent_compile
        install_agent
        echo "Tactical Agent Install is done"
	echo "Please wait about 5 min then run 'rmmagent-mac.sh enablepermissions'"
        exit 0;;
enablepermissions)
	config_securityandprivacy
	echo "Security and Privacy configuration is done"
	echo "If the Mac is running Sequoia then run 'rmmagent-mac.sh sequoiafix'"
        exit 0;;
sequoiafix)
	sequoia_fix
	echo "Sequoia Fix has been applied. Please reboot Mac for changes to take effect"
	exit 0;;
update)
        go_install
        agent_compile
        update_agent
        echo "Tactical Agent Update is done"
	echo "Please wait about 5 min then run 'rmmagent-mac.sh enablepermissions'"
        exit 0;;
uninstall)
        uninstall_agent
        uninstall_mesh
        echo "TacticalRMM/Mesh Agent Uninstall is complete"
        echo "You may need to manually remove the agents orphaned connections on TacticalRMM and MeshCentral"
        exit 0;;
esac
