QuickMed travel and escalation update

- Routes API v2 is attempted first for every transport mode.
- Legacy Google Directions is attempted if Routes v2 rejects a mode.
- Distance-based estimates remain available when the Google Cloud key is not authorized for either web-service API.
- Medication alerts are scheduled every 30 minutes until dose time, at dose time, at walking departure time, and at fastest-mode departure time.
- The top notification bell opens app notification history, not Health Reminders.
- Reset Reminders continues to clear reminder records and scheduled system notifications.

Google Cloud requirement: enable Routes API (and optionally Directions API), attach billing, and ensure the API key restriction matches com.example.quickmed plus the installed build certificate SHA-1.
