# Helper functions

default_get(attr) = value {
        value := policies[attr]
}

ns_get(ns, attr) = value {
        value := default_get("byNamespace")[ns][attr]
}

# Helper rules

defined_in_namespace[[ns, attr]] {
        default_get("byNamespace")
        default_get("byNamespace")[ns]
        default_get("byNamespace")[ns][attr]
}

invalid_default_policy[value] {
        not default_get("defaultPolicy") == "accept"
        not default_get("defaultPolicy") == "reject"
        not default_get("defaultPolicy") == "scan-result"
        value := default_get("defaultPolicy")
}

invalid_default_policy["<empty>"] {
        not default_get("defaultPolicy")
}

invalid_report_pending_policy[value] {
        not default_get("reportPending") == "accept"
        not default_get("reportPending") == "reject"
        value := default_get("reportPending")
}

invalid_report_pending_policy["<empty>"] {
        not default_get("reportPending")
}

invalid_scan_failed_policy[value] {
        not default_get("scanFailed") == "accept"
        not default_get("scanFailed") == "reject"
        value := default_get("scanFailed")
}

invalid_scan_failed_policy["<empty>"] {
        not default_get("scanFailed")
}

invalid_ns_default_policy[[ns,value]] {
        defined_in_namespace[[ns, "defaultPolicy"]]
        not ns_get(ns, "defaultPolicy") == "accept"
        not ns_get(ns, "defaultPolicy") == "reject"
        not ns_get(ns, "defaultPolicy") == "scan-result"
        value := ns_get(ns, "defaultPolicy")
}


invalid_ns_report_pending_policy[[ns,value]] {
        defined_in_namespace[[ns, "reportPending"]]
        not ns_get(ns, "reportPending") == "accept"
        not ns_get(ns, "reportPending") == "reject"
        value := ns_get(ns, "reportPending")
}

invalid_ns_scan_failed_policy[[ns,value]] {
        defined_in_namespace[[ns, "scanFailed"]]
        not ns_get(ns, "scanFailed") == "accept"
        not ns_get(ns, "scanFailed") == "reject"
        value := ns_get(ns, "scanFailed")
}

# Configuration errors

config_error["AdmissionRequest is missing in input"] {
        not input.AdmissionRequest
}


config_error["ScanReport is missing in input"] {
        not input.ScanReport
}

config_error[msg] {
        invalid_default_policy[value]
        msg = sprintf("Invalid scanPolicies.defaultPolicy - '%s'", [value])
}

config_error[msg] {
        some value
        invalid_report_pending_policy[value]
        msg :=  sprintf("Invalid scanPolicies.reportPending - '%s'", [value])
}

config_error[msg] {
        some value
        invalid_scan_failed_policy[value]
        msg := sprintf("Invalid scanPolicies.scanFailed - '%s'", [value])
}

config_error[msg] {
        some ns, value
        invalid_ns_default_policy[[ns,value]]
        msg := sprintf("Invalid scanPolicies.defaultPolicy for namespace '%s' - '%s'", [ns, value])
}

config_error[msg] {
        some ns, value
        invalid_ns_report_pending_policy[[ns,value]]
        msg := sprintf("Invalid scanPolicies.reportPending for namespace '%s' - '%s'", [ns, value])
}

config_error[msg] {
        some ns, value
        invalid_ns_scan_failed_policy[[ns,value]]
        msg := sprintf("Invalid scanPolicies.scanFailed for namespace '%s' - '%s'", [ns, value])
}

# Scan result helpers

scan_result_rejected {
        input.ScanReport.Status == "rejected"
}

scan_result_failed {
        input.ScanReport.Status == "scan_failed"
}

scan_result_not_available {
        input.ScanReport.Status == "report_not_available"
}

scan_result_unexpected {
        not input.ScanReport.Status == "accepted"
        not input.ScanReport.Status == "rejected"
        not input.ScanReport.Status == "scan_failed"
        not input.ScanReport.Status == "report_not_available"
}

# Default policies

default_deny_image["Image rejected by default policy"] {
        not defined_in_namespace[[namespace, "defaultPolicy"]]
        not default_always_scan_result
        not default_always_accept
        default_get("defaultPolicy") == "reject"
}

default_deny_image["Image rejected - scan report is pending"] {
        not defined_in_namespace[[namespace, "reportPending"]]
        not default_always_accept
        default_get("reportPending") == "reject"
        scan_result_not_available
}

default_deny_image["Image rejected - scan failed"] {
        not defined_in_namespace[[namespace, "scanFailed"]]
        not default_always_accept
        default_get("scanFailed") == "reject"
        scan_result_failed
}

default_check_scan_result {
        not default_always_accept
        default_get("defaultPolicy") == "scan-result"
}

default_deny_image["Image rejected by scan-result"] {
        not defined_in_namespace[[namespace, "defaultPolicy"]]
        default_check_scan_result
        scan_result_rejected
}

    default_deny_image[msg] {
        not defined_in_namespace[[namespace, "defaultPolicy"]]
        default_check_scan_result
        scan_result_unexpected
        msg := sprintf("Image rejected - Unexpected ScanReport Status value - '%s'", [input.ScanReport.Status])
}

# Default per-registry settings

default_always_accept {
        not defined_in_namespace[[namespace, "alwaysAccept"]]
        some i
        prefix := default_get("alwaysAccept")[i]
        startswith(input.ScanReport.ImageAndTag, prefix)
}

default_always_scan_result {
        not defined_in_namespace[[namespace, "alwaysScanResult"]]
        some i
        prefix := default_get("alwaysScanResult")[i]
        startswith(input.ScanReport.ImageAndTag, prefix)
}

default_check_scan_result {
        default_always_scan_result
}

default_always_reject[msg] {
        not defined_in_namespace[[namespace, "alwaysReject"]]
        some i
        prefix := default_get("alwaysReject")[i]
        startswith(input.ScanReport.ImageAndTag, prefix)
        msg := sprintf("Image rejected - prefix '%s' is blacklisted", [prefix])
}

default_deny_image[msg] {
        default_always_reject[msg]
}

# Per-namespace policies

ns_deny_image[[ns, "Image rejected by namespace policy"]] {
        defined_in_namespace[[ns, "defaultPolicy"]]
        ns_get(ns, "defaultPolicy") == "reject"
}

ns_deny_image[[ns, "Image rejected in namespace - scan report is pending"]] {
        defined_in_namespace[[ns, "reportPending"]]
        ns_get(ns, "reportPending") == "reject"
        input.ScanReport.Status == "report_not_available"
}

ns_deny_image[[ns, "Image rejected in namespace - scan failed"]] {
        defined_in_namespace[[ns, "scanFailed"]]
        ns_get(ns, "scanFailed") == "reject"
        input.ScanReport.Status == "scan_failed"
}

ns_check_scan_result[ns] {
        not ns_always_accept[ns]
        defined_in_namespace[[ns, "defaultPolicy"]]
        ns_get(ns, "defaultPolicy") == "scan-result"
}

ns_deny_image[[ns, "Image rejected in namespace by scan-result"]] {
        ns_check_scan_result[ns]
        scan_result_rejected
}

# Per-namespace and registry black/white list settings

ns_always_accept[ns] {
        defined_in_namespace[[ns, "alwaysAccept"]]
        some i
        prefix := ns_get(ns, "alwaysAccept")[i]
        startswith(input.ScanReport.ImageAndTag, prefix)
}

ns_always_scan_result[ns] {
        defined_in_namespace[[ns, "alwaysScanResult"]]
        some i
        prefix := ns_get(ns, "alwaysScanResult")[i]
        startswith(input.ScanReport.ImageAndTag, prefix)
}

ns_check_scan_result[ns] {
        ns_always_scan_result[ns]
}

ns_always_reject[[ns,msg]] {
        defined_in_namespace[[ns, "alwaysReject"]]
        some i
        prefix := ns_get(ns, "alwaysReject")[i]
        startswith(input.ScanReport.ImageAndTag, prefix)
        msg := sprintf("Image rejected - prefix '%s' is blacklisted", [prefix])
}

ns_deny_image[[ns, msg]] {
        ns_always_reject[[ns, msg]]
}

# Final decission making

deny_image[msg] {
        config_error[msg]
}

deny_image[msg] {
        default_deny_image[msg]
}

deny_image[msg] {
        some ns_msg
        ns_deny_image[[namespace, ns_msg]]
        msg := sprintf("Namespace '%s' policy - %s", [namespace, ns_msg])
}