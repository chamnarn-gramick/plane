app_name = "crm_ultra"
app_title = "CRM Ultra"
app_publisher = "Chamnarn"
app_description = "CRM Ultra-style sales CRM customizations for ERPNext / Frappe"
app_email = "chamnarn@gmail.com"
app_license = "MIT"

# Apps this app depends on
required_apps = ["frappe/erpnext"]

# Installation
# ------------
after_install = "crm_ultra.install.after_install"

# Fixtures
# --------
# Records that are shipped with the app and imported on `bench migrate`.
fixtures = [
    {
        "dt": "Custom Field",
        "filters": [["module", "=", "CRM Ultra"]],
    },
    {
        "dt": "Property Setter",
        "filters": [["name", "in", ["Quotation-naming_series-options"]]],
    },
    {
        "dt": "Workflow State",
        "filters": [["name", "in", ["Pending Approval"]]],
    },
    {
        "dt": "Workflow Action Master",
        "filters": [["name", "in", ["Submit for Approval"]]],
    },
    {
        "dt": "Workflow",
        "filters": [["name", "in", ["CRM Ultra Quotation Approval"]]],
    },
    {
        "dt": "Print Format",
        "filters": [
            ["name", "in", ["CRM Ultra Quotation TH", "CRM Ultra Tax Invoice TH"]]
        ],
    },
    {
        "dt": "Number Card",
        "filters": [["module", "=", "CRM Ultra"]],
    },
    {
        "dt": "Dashboard Chart",
        "filters": [["module", "=", "CRM Ultra"]],
    },
    {
        "dt": "Dashboard",
        "filters": [["module", "=", "CRM Ultra"]],
    },
]

# Scheduled Tasks
# ---------------
scheduler_events = {
    "daily": [
        # แจ้งเตือนใบเสนอราคาที่ใกล้หมดอายุ
        "crm_ultra.tasks.notify_expiring_quotations",
    ],
}
