# Smart reminder format update

The older interval reminder sequence has been removed.

For every medication time, QuickMed now schedules:

1. 30 minutes before the departure time for the slowest available transport mode.
2. 30 minutes before the departure time for the fastest available transport mode.
3. At the exact departure time for the slowest available transport mode.
4. At the latest safe departure time for the fastest available transport mode.
5. At the exact medication time.

The first four alerts include the medicine, destination, travel duration for every available transport mode, and the notification timestamp. The final alert contains only the due-now medication message.

When a new medication schedule is saved, QuickMed cancels all locally scheduled legacy alerts and deletes the signed-in user's older reminder and app-notification records before saving the new format.

Note: Android local notifications cannot independently check live location or user response at trigger time. The fastest-mode alert is therefore scheduled as the safety escalation at the latest safe departure time. A true “only if still at the same place and no response” check requires an Android foreground/background location service or server-side push workflow.

## User response
The first four Android alerts include an **I'm moving** action. Choosing it cancels the later fastest-mode escalation notification. If the patient does not choose the action, the safety escalation remains scheduled.
