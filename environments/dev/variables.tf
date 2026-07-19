variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
  sensitive   = true # hide it from plan output & logs
}

## 1. Resource Group variables
variable "rg_name" {
  type        = string
  description = "Resource group name"
  default     = "rg-dev-Sentinel-WUS3-01"
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "dev"
}

## 2. Network variables
variable "vnet_name" {
  type        = string
  description = "Virtual network name"
  default     = "vnet-dev-Sentinel-WUS3-01"
}

variable "subnet_name" {
  type        = string
  description = "Subnet name"
  default     = "dev-subnet"
}

variable "client_ip" {
  type        = string
  description = "Client IP address for SSH access"
  sensitive   = true
}

## 3. VM variables
variable "WinSer1_VM_admin_password" {
  type        = string
  description = "Admin password for the Windows VM"
  sensitive   = true
}

variable "WinSer1_VM" {
  type        = string
  description = "Name of the Windows VM"
  default     = "WinSer1-VM-Dev"
}

variable "UbuDoc1_VM" {
  type        = string
  description = "Name of the Ubuntu VM"
  default     = "UbuDoc1-VM-Dev"
}

variable "pub_key" {
  type        = string
  description = "SSH public key to add to the VM"
  sensitive   = true
}

## 4. Log Analytics Workspace variables
variable "law_name" {
  type        = string
  description = "Log Analytics Workspace name"
  default     = "law-dev-Sentinel-WUS3"
}




##DCR variables

# Basic performance counter list:
variable "counter_specifiers" {
  type        = list(string)
  description = "List of Windows/Linux performance counters to collect"
  default = [
    # Windows counters (escaped with double backslashes)
    "\\Processor Information(_Total)\\% Processor Time",
    "\\Processor Information(_Total)\\% Privileged Time",
    "\\Processor Information(_Total)\\% User Time",
    "\\Processor Information(_Total)\\Processor Frequency",
    "\\System\\Processes",
    "\\Process(_Total)\\Thread Count",
    "\\Process(_Total)\\Handle Count",
    "\\System\\System Up Time",
    "\\System\\Context Switches/sec",
    "\\System\\Processor Queue Length",

    "\\Memory\\% Committed Bytes In Use",
    "\\Memory\\Available Bytes",
    "\\Memory\\Committed Bytes",
    "\\Memory\\Cache Bytes",
    "\\Memory\\Pool Paged Bytes",
    "\\Memory\\Pool Nonpaged Bytes",
    "\\Memory\\Pages/sec",
    "\\Memory\\Page Faults/sec",
    "\\Process(_Total)\\Working Set",
    "\\Process(_Total)\\Working Set - Private",

    "\\LogicalDisk(_Total)\\% Disk Time",
    "\\LogicalDisk(_Total)\\% Disk Read Time",
    "\\LogicalDisk(_Total)\\% Disk Write Time",
    "\\LogicalDisk(_Total)\\% Idle Time",
    "\\LogicalDisk(_Total)\\Disk Bytes/sec",
    "\\LogicalDisk(_Total)\\Disk Read Bytes/sec",
    "\\LogicalDisk(_Total)\\Disk Write Bytes/sec",
    "\\LogicalDisk(_Total)\\Disk Transfers/sec",
    "\\LogicalDisk(_Total)\\Disk Reads/sec",
    "\\LogicalDisk(_Total)\\Disk Writes/sec",
    "\\LogicalDisk(_Total)\\Avg. Disk sec/Transfer",
    "\\LogicalDisk(_Total)\\Avg. Disk sec/Read",
    "\\LogicalDisk(_Total)\\Avg. Disk sec/Write",
    "\\LogicalDisk(_Total)\\Avg. Disk Queue Length",
    "\\LogicalDisk(_Total)\\Avg. Disk Read Queue Length",
    "\\LogicalDisk(_Total)\\Avg. Disk Write Queue Length",
    "\\LogicalDisk(_Total)\\% Free Space",
    "\\LogicalDisk(_Total)\\Free Megabytes",

    "\\Network Interface(*)\\Bytes Total/sec",
    "\\Network Interface(*)\\Bytes Sent/sec",
    "\\Network Interface(*)\\Bytes Received/sec",
    "\\Network Interface(*)\\Packets/sec",
    "\\Network Interface(*)\\Packets Sent/sec",
    "\\Network Interface(*)\\Packets Received/sec",
    "\\Network Interface(*)\\Packets Outbound Errors",
    "\\Network Interface(*)\\Packets Received Errors",
    # Linux counters (no escaping needed)
    "Processor(*)\\% Processor Time",
    "Processor(*)\\% Idle Time",
    "Processor(*)\\% User Time",
    "Processor(*)\\% Nice Time",
    "Processor(*)\\% Privileged Time",
    "Processor(*)\\% IO Wait Time",
    "Processor(*)\\% Interrupt Time",

    "Memory(*)\\Available MBytes Memory",
    "Memory(*)\\% Available Memory",
    "Memory(*)\\Used Memory MBytes",
    "Memory(*)\\% Used Memory",
    "Memory(*)\\Pages/sec",
    "Memory(*)\\Page Reads/sec",
    "Memory(*)\\Page Writes/sec",
    "Memory(*)\\Available MBytes Swap",
    "Memory(*)\\% Available Swap Space",
    "Memory(*)\\Used MBytes Swap Space",
    "Memory(*)\\% Used Swap Space",

    "Logical Disk(*)\\% Free Inodes",
    "Logical Disk(*)\\% Used Inodes",
    "Logical Disk(*)\\Free Megabytes",
    "Logical Disk(*)\\% Free Space",
    "Logical Disk(*)\\% Used Space",
    "Logical Disk(*)\\Logical Disk Bytes/sec",
    "Logical Disk(*)\\Disk Read Bytes/sec",
    "Logical Disk(*)\\Disk Write Bytes/sec",
    "Logical Disk(*)\\Disk Transfers/sec",
    "Logical Disk(*)\\Disk Reads/sec",
    "Logical Disk(*)\\Disk Writes/sec",

    "Network(*)\\Total Bytes Transmitted",
    "Network(*)\\Total Bytes Received",
    "Network(*)\\Total Bytes",
    "Network(*)\\Total Packets Transmitted",
    "Network(*)\\Total Packets Received",
    "Network(*)\\Total Rx Errors",
    "Network(*)\\Total Tx Errors",
    "Network(*)\\Total Collisions",

    "System(*)\\Uptime",
    "System(*)\\Load1",
    "System(*)\\Load5",
    "System(*)\\Load15",
    "System(*)\\Users",
    "System(*)\\Unique Users",
    "System(*)\\CPUs",

    "Process(*)\\Pct User Time",
    "Process(*)\\Pct Privileged Time",
    "Process(*)\\Used Memory",
    "Process(*)\\Virtual Shared Memory"
  ]
}

# --- Windows Security Events via AMA filter selection ---
# xPath queries below implement the "AllEvents" filter used by the Sentinel
# connector. Swap these for the Common/Minimal event-ID lists (or your own
# custom XPath) if you want a narrower collection - see:
# https://learn.microsoft.com/azure/sentinel/data-connectors/windows-security-events-via-ama
variable "windows_security_xpath_queries" {
  type = list(string)
  default = [
    "Security!*"
  ]
}

# --- Syslog facilities (plain syslog, NOT used for CEF ices) ---
variable "syslog_facilities" {
  type    = list(string)
  default = ["auth", "authpriv", "cron", "daemon", "kern", "syslog", "user"]
}

variable "syslog_log_levels" {
  type    = list(string)
  default = ["Warning", "Error", "Critical", "Alert", "Emergency"]
}

# --- CEF facilities (must NOT overlap with syslog_facilities above, to avoid
# the same event being ingested twice into Syslog and CommonSecurityLog) ---
variable "cef_facilities" {
  type    = list(string)
  default = ["local4"]
}

variable "cef_log_levels" {
  type    = list(string)
  default = ["*"]
}