output "WinSer1_VM" {
  value = {
    vm_id          = module.WinSer1_VM.vm_id
    public_ip      = module.WinSer1_VM.public_ip
    admin_username = module.WinSer1_VM.admin_username
  }
}

output "UbuDoc1_VM" {
  value = {
    vm_id          = module.UbuDoc1_VM.vm_id
    public_ip      = module.UbuDoc1_VM.public_ip
    admin_username = module.UbuDoc1_VM.admin_username
  }
}