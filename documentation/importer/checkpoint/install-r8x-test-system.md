# install R8x test system

- download r80.40 all-in-one system from <https://supportcenter.checkpoint.com/supportcenter/portal/role/supportcenterUser/page/default.psml/media-type/html?action=portlets.DCFileAction&eventSubmit_doGetdcdetails=&fileid=101083>
-  install on virtual box machine
  - bridged fixed ip virtual box using linux 64-bit kernel 2.4/2.6/3/4
  - at least 8 GB RAM
  - at least 2 CPUs
  - during install dialogue, choose mgmt + gateway install (or later try multi domain mgmt) 
- connect to mgmt interface via https and run first time wizard (keep clients can connect from any host), restart
- connect via ssh and set expert password
- also run

        add user fworch userid 1000 homedir /home/fworch
        add rba user fworch roles monitorRole
        set user fworch password DC1gus.
        add allowed-client network ipv4-address 10.8.6.0 mask-length 24
        add allowed-client network ipv4-address 192.168.100.0 mask-length 24
        api reconf 

# how to set api to listen for all gui clients without GUI client?

## useful commands for later usage

    show rba all
    show route all
    show route static all


## Check Point R8x API access ideas

a) increase api access speed
```console
[--sync] {true|false}
	Synchronous execution of task - commands that generate the task will wait until the task is finished.
	Default {true}
	Environment variable: MGMT_CLI_SYNC
```
b) add 2FA

        mgmt_cli login --client-cert path-to-certificate-file.p12 password secret