# Security and Privacy

## Monitoring Data

The monitoring script in this repository may record local system
information, including:

- Process names
- Process IDs
- Executable paths
- Process start times
- Memory usage
- Handle counts
- Thread counts
- CPU usage
- System timestamps

Some of this information may reveal personal or sensitive details.

## Review Before Publishing

Before publishing monitoring output, remove or anonymize:

- Windows usernames
- Personal directory paths
- Project names
- Repository names
- Local application paths
- Email addresses
- IP addresses
- Proxy addresses
- API endpoints
- Codex thread or conversation identifiers
- Computer serial numbers
- Unrelated private application names

For example, replace:

```text
C:\Users\ActualUsername\Documents\PrivateProject
