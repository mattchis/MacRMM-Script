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
        echo "Arg 2: System type 'amd64' 'x86' 'arm64' 'armv6'"
        echo "Arg 3: Mesh agent URL"
        echo "Arg 4: API URL"
        echo "Arg 5: Client ID"
        echo "Arg 6: Site ID"
        echo "Arg 7: Auth Key"
        echo "Arg 8: Agent Type 'server' or 'workstation'"
        echo ""
        echo "List of UNINSTALL argument (no argument name):"
        echo "Arg 1: 'uninstall'"
        echo "Arg 2: Mesh agent FQDN (i.e. mesh.domain.com)"
        echo "Arg 3: Mesh agent id (The id needs to have single quotes around it)"
        echo ""
        echo "Only argument 1 is needed for update"
        echo ""
        exit 0
fi

if [[ $1 != "install" && $1 != "update" && $1 != "uninstall" ]]; then
        echo "First argument can only be 'install' or 'update' or 'uninstall' !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "install" && $2 == "" ]]; then
        echo "Argument 2 (System type) is empty !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "install" && $2 != "amd64" && $2 != "arm64" ]]; then
        echo "This argument can only be 'amd64' 'arm64' !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "install" && $3 == "" ]]; then
        echo "Argument 3 (Mesh agent URL) is empty !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "install" && $4 == "" ]]; then
        echo "Argument 4 (API URL) is empty !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "install" && $5 == "" ]]; then
        echo "Argument 5 (Client ID) is empty !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "install" && $6 == "" ]]; then
        echo "Argument 6 (Site ID) is empty !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "install" && $7 == "" ]]; then
        echo "Argument 7 (Auth Key) is empty !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "install" && $8 == "" ]]; then
        echo "Argument 8 (Agent Type) is empty !"
        echo "Type help for more information"
        exit 1
fi

if [[ $1 == "install" && $8 != "server" && $8 != "workstation" ]]; then
        echo "First argument can only be 'server' or 'workstation' !"
        echo "Type help for more information"
        exit 1
fi

## Setting var for easy scription
system=$2
mesh_url=$3
rmm_url=$4
rmm_client_id=$5
rmm_site_id=$6
rmm_auth=$7
rmm_agent_type=$8

go_url_amd64="https://go.dev/dl/go1.20.2.darwin-amd64.pkg"
go_url_arm64="https://go.dev/dl/go1.20.2.darwin-arm64.pkg"

function go_install() {
        ## Installing golang
        case $system in
        amd64)
          sudo curl -L -o /tmp/golang.pkg $go_url_amd64
        ;;
        arm64)
          sudo curl -L -o /tmp/golang.pkg $go_url_arm64
        ;;
        esac
        
        sudo installer -pkg /tmp/golang.pkg -target /usr/local/go
        sudo rm /tmp/golang.pkg

        source /etc/profile

        echo "Golang Install Done !"
}

function install_mesh() {
        ## Installing mesh agent
        sudo curl -L -o /tmp/meshagent $mesh_url
        sudo chmod +x /tmp/meshagent
        sudo mkdir /opt/tacticalmesh
        sudo /tmp/meshagent -install --installPath="/opt/tacticalmesh"
        sudo rm /tmp/meshagent
        sudo rm /tmp/meshagent.msh
}

function getCSREQBlob(){
    # Sign the app
    sudo codesign --detached /opt/tacticalmesh/meshagent.sig -s - /opt/tacticalmesh/meshagent

    # Get the requirement string from codesign
    req_str=$(sudo codesign -d -r- --detached /opt/tacticalmesh/meshagent.sig /opt/tacticalmesh/meshagent 2>&1 | awk -F ' => ' '/designated/{print $2}')
    
    # Convert the requirements string into it's binary representation
    # csreq requires the output to be a file so we just throw it in /tmp
    echo "$req_str" | sudo csreq -r- -b /tmp/csreq.bin
    
    # Convert the binary form to hex, and print it nicely for use in sqlite
    req_hex="X'$(sudo xxd -p /tmp/csreq.bin | tr -d '\n')'"
    
    echo "$req_hex"
    
    # Remove csqeq.bin
    sudo rm -f "/tmp/csreq.bin"
}

function agent_compile() {
        ## Compiling and installing tactical agent from github
        echo "Agent Compile begin"
        sudo curl -L -o /tmp/rmmagent.zip https://github.com/amidaware/rmmagent/archive/refs/heads/master.zip
        sudo unzip /tmp/rmmagent.zip -d /tmp/
        sudo rm /tmp/rmmagent.zip
        case $system in
        amd64)
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
        sudo cp /tmp/temp_rmmagent /usr/local/bin/rmmagent
        sudo /tmp/temp_rmmagent -m install -meshdir /opt/tacticalmesh -api $rmm_url -client-id $rmm_client_id -site-id $rmm_site_id -agent-type $rmm_agent_type -auth $rmm_auth
        sudo rm /tmp/temp_rmmagent
}

function update_agent() {
        sudo launchctl unload /Library/LaunchDaemons/tacticalagent.plist

        sudo cp /tmp/temp_rmmagent /opt/tacticalagent/tacticalagent
        sudo rm /tmp/temp_rmmagent

        sudo launchctl load -w /Library/LaunchDaemons/tacticalagent.plist
}

function config_securityandprivacy () {
        # Adding permissions to macOS to allow Accessibility, Screen Capture, and All File Access to the meshagent
        echo "Applying Security and Privacy Exceptions"
        req_hex="$(getCSREQBlob)"
        sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "REPLACE INTO access VALUES('kTCCServiceAccessibility','/opt/tacticalmesh/meshagent',1,2,4,1,$req_hex,NULL,0,NULL,NULL,0,NULL);"
        sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "REPLACE INTO access VALUES('kTCCServiceScreenCapture','/opt/tacticalmesh/meshagent',1,2,4,1,$req_hex,NULL,0,NULL,NULL,0,NULL);"
        sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/opt/tacticalmesh/meshagent',1,2,4,1,$req_hex,NULL,0,NULL,NULL,0,NULL);"
}

function uninstall_agent() {
        sudo launchctl unload /Library/LaunchDaemons/tacticalagent.plist
        sudo rm /Library/LaunchDaemons/tacticalagent.plist
        sudo rm -Rf /opt/tacticalagent/
        sudo rm /etc/tacticalagent
}

function uninstall_mesh() {
        sudo launchctl unload /Library/LaunchDaemons/meshagent.plist
        sudo /opt/tacticalmesh/meshagent -fulluninstall
        rm -Rf /opt/tacticalmesh
        sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "delete from access where client='/opt/tacticalmesh/meshagent';"
}

case $1 in
install)
        #check_profile
        go_install
        install_mesh
        agent_compile
        install_agent
        config_securityandprivacy
        echo "Tactical Agent Install is done"
        exit 0;;
update)
        #check_profile
        go_install
        agent_compile
        update_agent
        config_securityandprivacy
        echo "Tactical Agent Update is done"
        exit 0;;
uninstall)
        #check_profile
        uninstall_agent
        uninstall_mesh
        echo "Tactical Agent Uninstall is done"
        echo "You may need to manually remove the agents orphaned connections on TacticalRMM and MeshCentral"
        exit 0;;
esac