# PowershellTool
Useful Powershell Tool Suites 

# Updates - 20261109 -  MulThreadsXG5_sample.ps1  / MulThreadsXG5_readme.pdf
Find attached a lightweight PowerShell script that can be used for basic concurrent SOAP API testing and response time verification.
This utility was originally prepared for large enterprise customer and lightweight performance validation scenarios, especially in environments where dedicated testing tools may not be readily available.

A few important notes regarding usage:
•	The script is intended for internal testing and diagnostic purposes only.
•	It is designed for lightweight concurrent validation rather than large-scale stress or load testing.
•	Please review and update endpoint URLs, credentials, and request payloads before use.
•	The optional SSL certificate bypass setting should only be enabled in non-production or controlled testing environments.
•	It is recommended to use moderate thread and request settings to avoid unintended impact on shared systems.

The script includes:
•	Concurrent request execution using PowerShell Runspaces
•	Response time statistics
•	Success/failure tracking
•	Connection warm-up logic
•	Configurable thread and timeout settings

Hopefully this can serve as a convenient reference utility for project teams during integration testing or onsite support activities.
Please feel free to adapt it as needed based on your project requirements and local testing policies.
