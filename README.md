# Sample Terraform code to drive APIC controller

Started: 2020.06.25

## Overview

This is an ongoing attempt to drive the fabric entirely as code by working on this prototype.
Currently being tested on following environment: 

APIC version 4.2(4i).
Terraform v0.12.28 - provider.aci v0.3.1
Ansible 2.9.10*
Running on MacOS Catalina / Homebrew

Most of the Terraform code is still in 01-underlay-policy folder. Current idea is to separate underlay and overlay/segmentation policy to isolate changes and impact while keep the code managable. Downside is that overlay policy will need to pull out existing policy e.g. l3Out in order to reference to it. Still experimenting with this idea.
Gaps in Terraform provider are being filled with aci_rest module.

*2020.07.13 - migrated terraform gap to Terraform aci_rest provider. We can now run entirely on Terraform with one caveat: aci_rest call doesn't seem to properly keep states, meaning out-of-band changes won't get updated. Workaround is to taint those aci_rest instances before terraform apply. "tf-taint.sh" script is provided for this purpose.*

Identified gaps are noted throughout the code where it is found. Notably:

System policy
- route reflector policy
- OOB management IP address
- DNS policy
- time zone
- NTP policy
- Port profile - to set some of 40G ports to downlinks

Fabric access policy
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