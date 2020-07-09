# !!! move to ansbile-gap. DO NOT USE

# tenant-irvsdc2.tf
# terraform file for APIC policy as code
# specific to tenant: irvsdc2
# addressing gaps with aci_rest
# since 2020.07.05

# !!! gap - no provider to bind application epg to aep, doing it manually
# resource "aci_rest" "rest-bind_aep_to_epg1" {
#   path = "/api/node/mo/uni/infra/attentp-irvsdc2-isn_aep/gen-default.json"
#   payload = <<EOF
#   {
#     "infraRsFuncToEpg": {
#       "attributes": {
#         "tDn": "uni/tn-irvsdc2/ap-irvsdc2-infra_ap/epg-vl697-10_95_19_96_27_epg",
#         "status": "created,modified",
#         "encap": "vlan-697"
#       },
#       "children": []
#     }
#   }
#   EOF
# }

# and this is how to delete
# resource "aci_rest" "rest-delete-bind_epg_to_aep1" {
#   path = "/api/node/mo/uni/infra/attentp-irvsdc2-isn_aep/gen-default/rsfuncToEpg-[uni/tn-irvsdc2/ap-irvsdc2-infra_ap/epg-vl697-10_95_19_96_27_epg].json"
#   payload = <<EOF
#     {
#       "infraRsFuncToEpg": {
#         "attributes": {
#         "dn": "uni/infra/attentp-irvsdc2-isn_aep/gen-default/rsfuncToEpg-[uni/tn-irvsdc2/ap-irvsdc2-infra_ap/epg-vl697-10_95_19_96_27_epg]",
#         "status": "deleted"
#         },
#         "children": []
#       }
#     }
#   EOF
# }

# !!! gap - bind l3out to vrf - address in -rest.tf
# resource "aci_rest" "rest-set_vrf_in_l3out1" {
#   path = "api/node/mo/uni/tn-irvsdc2/out-irvsdc2-main_l3out.json"
#   payload = <<EOF
#     {
#       "l3extOut": {
#         "attributes": {
#           "dn": "uni/tn-irvsdc2/out-irvsdc2-main_l3out",
#           "status": "modified"
#         },
#         "children": [
#           {
#             "l3extRsEctx": {
#               "attributes": {
#                 "tnFvCtxName": "main_vrf"
#               },
#               "children": []
#             }
#           }
#         ]
#       }
#     }
#   EOF
# }

# !!! gap - bind l3out to l3dom - address in -rest.tf
# resource "aci_rest" "rest-set_l3dom_in_l3out1" {
#   path = "api/node/mo/uni/tn-irvsdc2/out-irvsdc2-main_l3out.json"
#   payload = <<EOF
#     {
#       "l3extOut": {
#         "attributes": {
#           "dn": "uni/tn-irvsdc2/out-irvsdc2-main_l3out",
#           "status": "modified"
#         },
#         "children": [
#           {
#             "l3extRsL3DomAtt": {
#               "attributes": {
#                 "tDn": "uni/l3dom-irvsdc-isn_l3dom",
#                 "status": "created"
#               },
#               "children": []
#             }
#           }
#         ]
#       }
#     }
#   EOF
# }

# !!! gap - also don't know how to enable ospf on l3out
# resource "aci_rest" "rest-enable_ospf_on_l3out1" {
#   path = "/api/node/mo/uni/tn-irvsdc2/out-irvsdc2-main_l3out/ospfExtP.json"
#   payload = <<EOF
#     {
#       "ospfExtP": {
#         "attributes": {
#           "dn": "uni/tn-irvsdc2/out-irvsdc2-main_l3out/ospfExtP",
#           "areaId": "65201",
#           "status": "created"
#         },
#         "children": []
#       }
#     }
#   EOF
# }

# !!! gap - don't know how to set svi ip address in logical interface profile
# !!! gap - no ospf interface profile so can't attach ospf interface policy to logical interface profile