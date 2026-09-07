output "Kali1_VM" {
  value = {
    vm_id          = module.Kali1_VM.vm_id
    public_ip      = module.Kali1_VM.public_ip
    admin_username = module.Kali1_VM.admin_username
  }
}

output "WinTarget1_VM" {
  value = {
    vm_id          = module.WinTarget1_VM.vm_id
    public_ip      = module.WinTarget1_VM.public_ip
    admin_username = module.WinTarget1_VM.admin_username
  }
}
