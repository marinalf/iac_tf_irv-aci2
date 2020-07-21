# Sample Terraform code to drive an ACI fabric

Started: 2020.06.25

## Overview

Sample Terraform code to drive ACI fabric from a near-empty state to forwarding traffic over l3Out.

Currently being tested on following environment: 
- APIC version 4.2(4i).
- Terraform v0.12.28 - provider.aci v0.3.1
- Ansible 2.9.10* (no longer used as of 0.1.1)
- Running on MacOS Catalina / Homebrew

In the current version all of the Terraform codes are in 01-underlay-policy folder.

*2020.07.13 - migrated terraform gap to Terraform aci_rest provider. We can now run entirely on Terraform with one caveat: aci_rest call doesn't seem to properly keep states, meaning out-of-band changes won't get updated. Workaround is to taint those aci_rest instances before terraform apply. "tf-taint.sh" script is provided for this purpose.*

System policy - these are done manually.
- route reflector policy
- OOB management IP address
- DNS policy
- time zone
- NTP policy
- Port profile - to set some of 40G ports to downlinks

Fabric access policy - these actions are being driven by aci_rest resources
- binding epg under AEP
- bind l3out to vrf
- bind l3out to l3dom
- enable ospf on an l3out
- set svi ip address in l3out logical interface profile

## Usage notes:

Terraform - in 01-underlay-policy folder
copy main.auto-sample.tfvars to main.auto.tfvars and populate APIC credentials

Ansible code to address the gap is available in 00-obsoleted folder. To use:
copy inventory-sample.yaml to inventory.yaml and edit APIC credentials

```bash
(in 01-underlay-policy folder)
$ ./00update.sh
```