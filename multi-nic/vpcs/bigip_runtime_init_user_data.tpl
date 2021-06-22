#!/bin/bash

# Create the logging directory
mkdir -p /var/log/cloud

# Define the logging destination
LOG_FILE=/var/log/cloud/startup-script.log

npipe=$(mktemp)
trap "rm -f $npipe" EXIT
mknod $npipe p
tee <$npipe -a $LOG_FILE /dev/ttyS0 &
exec 1>&-
exec 1>$npipe
exec 2>&1

# Make the config directory
mkdir -p /config/cloud

cat << "EOF" > /config/cloud/manual_run.sh
#!/bin/bash
f5-bigip-runtime-init --config-file /config/cloud/runtime-init-conf.yaml
EOF

cat << "EOF" > /config/cloud/runtime-init-conf.yaml
---
runtime_parameters:
  - name: SCHEMA_VERSION
    type: static
    value: 3.0.0
  - name: HOST_NAME
    type: metadata
    metadataProvider:
      environment: aws
      type: compute
      field: hostname
  - name: MGMT_IP
    type: metadata
    metadataProvider: 
      environment: aws
      type: network
      field: local-ipv4s
      index: 0
  - name: MGMT_SUBNET
    type: metadata
    metadataProvider:
      environment: aws
      type: network
      field: subnet-ipv4-cidr-block
      index: 0
  - name: MGMT_CIDR_MASK
    type: metadata
    metadataProvider:
      environment: aws
      type: network
      field: subnet-ipv4-cidr-block
      index: 0
      ipcalc: bitmask
  - name: MGMT_GATEWAY
    type: metadata
    metadataProvider:
      environment: aws
      type: network
      field: local-ipv4s
      index: 0
      ipcalc: first
  - name: MGMT_MASK
    type: metadata
    metadataProvider:
      environment: aws
      type: network
      field: subnet-ipv4-cidr-block
      index: 0
      ipcalc: mask
pre_onboard_enabled:
  - name: provision_rest
    type: inline
    commands:
      - /usr/bin/setdb provision.extramb 500
      - /usr/bin/setdb restjavad.useextramb true
      - /usr/bin/setdb setup.run false
      - /usr/bin/setdb provision.managementeth eth1
      - /usr/bin/setdb provision.tmmcount 1
bigip_ready_enabled:
  - name: aws_gwlb_configuration
    type: inline
    commands:
      - tmsh install sys license registration-key ${bigip_license}
extension_packages:
  install_operations:
    - extensionType: do
      extensionVersion: 1.20.0
extension_services:
  service_operations:
    - extensionType: do
      type: inline
      value:
        schemaVersion: 1.0.0
        class: Device
        async: true
        label: BIG-IP declaration for declarative onboarding
        Common:
          class: Tenant
          provision:
            ltm: nominal
            asm: nominal
          dbVars:
            class: DbVariables
            provision.extramb: 500
            restjavad.useextramb: true
            provision.managementeth: eth1
            provision.tmmcount: 1
            configsync.allowmanagement: enable            
post_onboard_enabled:
  - name: manual_tmsh_configuration
    type: inline
    commands:
      - tmsh modify net user admin password ${bigipAdminPassword}
      - tmsh create net vlan dataplane interfaces add { 1.1 { untagged }} mtu 9001
      - tmsh create net route-domain dataplane id 1 vlans add { dataplane }
      - tmsh create net self inband-mgmt address `printf {{{ MGMT_IP }}} | cut -d "/" -f1`%1/`printf {{{ MGMT_IP }}} | cut -d "/" -f2` vlan dataplane allow-service all
      - tmsh create net route dataplane-default network 0.0.0.0%1 gw {{{ MGMT_GATEWAY }}}%1
      - tmsh create net tunnels tunnel geneve local-address `printf {{{ MGMT_IP }}} | cut -d "/" -f1`%1 remote-address any%1 profile geneve
      - tmsh modify net route-domain dataplane vlans add { geneve } 
      - tmsh create ltm virtual health_check destination `printf {{{ MGMT_IP }}} | cut -d "/" -f1`%1:1 ip-protocol tcp mask 255.255.255.255 profiles add { http tcp } source 0.0.0.0%1/0 vlans-enabled vlans add { dataplane } 
      - tmsh create net self geneve-tunnel address 10.131.0.1%1/24 vlan geneve allow-service all
      - tmsh create net arp fake_arp_entry ip-address 10.131.0.2%1 mac-address ff:ff:ff:ff:ff:ff
      - tmsh create ltm node geneve-tunnel address 10.131.0.2%1 monitor none 
      - tmsh create ltm pool geneve-tunnel members add { geneve-tunnel:0 } monitor none 
      - tmsh create ltm virtual forwarding_vs destination 0.0.0.0%1:any ip-protocol any vlans-enabled vlans add { geneve } translate-address disabled source-port preserve-strict pool geneve-tunnel mask any
      - tmsh save /sys config
      - sed -i 's/        1\.1 {/        1\.0 {/g' /config/bigip_base.conf
      - reboot
EOF

### runcmd:
# Download

for i in {1..30}; do
    curl -fv --retry 1 --connect-timeout 5 -L https://cdn.f5.com/product/cloudsolutions/f5-bigip-runtime-init/v1.2.1/dist/f5-bigip-runtime-init-1.2.1-1.gz.run -o /var/config/rest/downloads/f5-bigip-runtime-init-1.2.1-1.gz.run && break || sleep 10
done

export F5_BIGIP_RUNTIME_INIT_LOG_LEVEL=silly

export F5_BIGIP_RUNTIME_INIT_LOG_LEVEL=silly && bash /var/config/rest/downloads/f5-bigip-runtime-init-1.2.1-1.gz.run -- "--cloud aws"

f5-bigip-runtime-init --config-file /config/cloud/runtime-init-conf.yaml --skip-telemetry