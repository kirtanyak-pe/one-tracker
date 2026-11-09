# Data safety form — answers

The app has no internet permission, so no data can leave the device through it.
Google defines "collected" as sent off the device, so:

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | Not applicable (nothing is collected) |
| Do you provide a way for users to request that their data is deleted? | Not applicable — data lives only on the phone; uninstalling or Settings › Clear data removes it |

Processed on the device only (not "collected", but worth saying in the
description): SMS (bank alerts), notifications from payment apps, contact
names/numbers/photos, amounts and merchants derived from them.

Backup: Android cloud backup is off (`allowBackup="false"`). The in-app backup
writes a file to a location the user picks; the app itself never uploads it.
