# main.tf
# main terraform file for APIC policy as code
# since 2020.06.24

provider "aci" {
  username = var.apic_user
  password = var.apic_password
  url      = var.apic_url
  insecure = var.apic_insecure
}

#####
# start from lower level and up
# section 1 - fabric policy
#####

# start with the basics
# - route reflector policy: terraform can't do this one yet
# site 1 = 65001
# site 2 = 65002
# - OOB management IP address
# - DNS policy
# - time zone


# NTP policy
# route reflector
# BGP


# start with fabric membership
resource "aci_fabric_node_member" "irv-aci2-n101" {
  serial  = "FDO22181CK7"
  pod_id  = "1"
  node_id = "101"
  name    = "irv-aci2-n101"
  role    = "spine"
}

resource "aci_fabric_node_member" "irv-aci2-n102" {
  serial  = "FDO22350P3U"
  pod_id  = "1"
  node_id = "102"
  name    = "irv-aci2-n102"
  role    = "spine"
}

resource "aci_fabric_node_member" "irv-aci2-n201" {
  serial  = "FDO22273SZD"
  pod_id  = "1"
  node_id = "201"
  name    = "irv-aci2-n201"
  role    = "leaf"
}

resource "aci_fabric_node_member" "irv-aci2-n202" {
  serial  = "FDO21270V6D"
  pod_id  = "1"
  node_id = "202"
  name    = "irv-aci2-n202"
  role    = "leaf"
}

