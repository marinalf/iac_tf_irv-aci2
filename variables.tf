# varilable file for Cisco ACI / APIC
# poomsawas@gmail.com

variable "apic_user" {
  description = "username to connect to apic controller"
  # default = ""
}

variable "apic_password" {
  description = "APIC controller password"
  # default = ""
}

variable "apic_url" {
  description = "APIC url e.g. https://apic1.cisco.com"
  # default = ""
}

variable "apic_insecure" {
  description = "set to true will ignore SSL cert validity"
  # default = ""
}
