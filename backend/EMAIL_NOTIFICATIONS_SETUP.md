# Missed social notification email setup

Deploy the PHP files in this directory beside the existing `db_config.php` and run
`email_notifications_setup.sql` once against the same database used by the app.
The changed `auth_customer_api.php`, `nearby_api.php`, `notifications_api.php`,
and `chat_api.php` files must be deployed together with
`email_notification_common.php` and `push_notifier.php`.

Configure these environment variables for the PHP web and CLI runtimes:

- `RESEND_API_KEY`: the Resend sending key for the verified `startupsgo.tech` domain.
- `RESEND_FROM_EMAIL`: a verified sender, for example
  `ChiyaBreak <noreply@startupsgo.tech>`.

For Hostinger setups where PHP environment variables are unavailable, the
preferred location is `resend_config.php` in the account directory above
`public_html` (two directories above `saas_api`). The PHP code also supports a
temporary `resend_config.php` beside the backend files inside `saas_api` if the
private location is not currently accessible. That temporary location is
inside the public web root and is less secure; use it only briefly, never
commit it, and move the file outside `public_html` as soon as possible. The
example file blocks direct web requests, but this does not make a public
directory as safe as a private location. Never put the real key in Flutter, a
public diagnostic endpoint, or a screenshot.
The private file should return an array with `RESEND_API_KEY` and
`RESEND_FROM_EMAIL` entries, for example:

```php
<?php
return [
    'RESEND_API_KEY' => 'YOUR_REAL_RESEND_KEY',
    'RESEND_FROM_EMAIL' => 'noreply@startupsgo.tech'
];
```

Follow, follow-back, and wave notifications are attempted immediately. Chat
message email notifications wait at least one minute and are sent only if the
recipient has not read or replied during that first minute. Reading or replying
after the one-minute window does not cancel an already-due email. Message emails
do not include private message text. If Resend is temporarily unavailable, the
item remains queued and is retried after five minutes.
Configure a Hostinger cron job to run `email_notifications_worker.php` once per
minute with the PHP CLI binary so delayed message emails and failed deliveries
are processed.

Customers must be signed in with their email and PIN, then explicitly enable
“Email me about app alerts” in Settings. Follow/follow-back, wave, and
message categories can be toggled separately. Message emails never contain
message text. Reading a message or replying within one minute prevents its
email notification.

## Temporary browser delivery test

For a one-time check, upload `email_delivery_test.php` beside `db_config.php` in
the live `saas_api` directory. The temporary page is restricted to the
`yurajpatwa114@gmail.com` address configured inside the PHP file, and sends no
more than one test every 15 minutes. Open
`https://startupsgo.tech/saas_api/email_delivery_test.php`, enter the owner
email, then choose **Check setup and send test email**. The tenant ID is
fixed to `startups_main`. The test uses the same environment variables or
private `resend_config.php` file as app-triggered email; it never displays the
API key.

The page checks the database connection, required tables, customer record,
saved email preferences, queued events, and whether any queued event currently
meets the worker's send conditions. A successful Resend response means Resend
accepted the test message; also check spam and the Resend dashboard. Delete
`email_delivery_test.php` from the server as soon as testing is complete.
