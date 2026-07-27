# QuickMed final route and reminder reset fix

- Travel cards now always show all five transport modes.
- Google Routes remains the primary source; conservative location-distance estimates are shown when the API key or Routes API rejects the request.
- Notification bodies include destination plus Driving, Boda, Public transit, Walking, and Cycling times.
- Refill Tracker was replaced by Reset Reminders. The action deletes the signed-in user’s Firestore reminders and cancels all scheduled local notifications after confirmation.
