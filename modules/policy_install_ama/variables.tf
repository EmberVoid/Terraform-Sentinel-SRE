variable "scope" {
  description = "Resource ID to assign the policies at (e.g. the Dev RG)"
  type        = string
}

variable "location" {
  description = "Location for the policy assignment's system-assigned identity"
  type        = string
}

variable "enable_linux" {
  description = "Whether to enable the Linux policy"
  type        = bool
  default     = true
}

variable "enable_windows" {
  description = "Whether to enable the Windows policy"
  type        = bool
  default     = true
}

variable "effect" {
  description = "The effect of the policy"
  type        = string
  default     = "DeployIfNotExists"
}

variable "assignment_name_prefix" {
  description = "The prefix for the policy assignment names"
  type        = string
  default     = "ama-install"
}