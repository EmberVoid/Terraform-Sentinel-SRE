output "linux_assignment_id" {
  value = try(module.ama_linux[0].assignment_id, null)
}

output "windows_assignment_id" {
  value = try(module.ama_windows[0].assignment_id, null)
}