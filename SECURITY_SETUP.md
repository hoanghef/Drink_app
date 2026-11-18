# P0 Firebase setup

The app creates COD orders through `placeOrder` and VNPay pending orders through
`createVnpayPayment` in `asia-southeast1`. Both require Firebase Authentication
and recalculate product prices using the same size offsets. A verified signed
`vnpayIpn` or the optionally enabled backend-only `reconcileVnpayPayment`
can change a VNPay order to `paid`. The browser redirect never changes
payment state.

## Manual configuration

1. Select a separate Firebase project for development. Enable Email/Password
   Authentication, Firestore, Storage and Cloud Functions. Configure billing if
   required by the Firebase plan for Functions. Set the correct project ID in
   Firebase CLI locally; no `.firebaserc` is committed.
2. Configure each Flutter platform for that project. Android currently has a
   project specific `google-services.json`; replace it when changing projects.
   iOS has no `GoogleService-Info.plist` in this repository.
3. Review and deploy `firestore.rules`, `storage.rules`, indexes and the
   Functions exported in `functions/index.js` together in a controlled release
   to the development project. Rules are **not** active
   merely because they exist in this repository. Do not deploy an order denying
   rule before its callable backend and app version are ready.
   Install the backend dependencies with `npm ci --prefix functions`. For a
   development project without VNPay, a scoped Firebase CLI command from the
   repo root is:

   ```sh
   ./functions/node_modules/.bin/firebase deploy --project <development-project-id> --only functions:placeOrder,functions:updateOrderStatus,functions:collectCodPayment,firestore,storage
   ```

   On Windows use `firebase.cmd`. Review the selected project and release the
   matching Flutter app; this command is documentation only and was not run.
4. Create an ordinary user account. From a trusted admin workstation with
   Application Default Credentials and suitable Firebase Auth IAM privileges,
   set `GOOGLE_CLOUD_PROJECT=<project-id>` and run
   `node functions/grant_admin.js <uid> grant`. Use `revoke` to remove access.
   The user must sign out and back in to refresh the ID token. Never run this
   tool from the mobile app or commit credentials. A profile `role` field is
   informational and does not grant access.
   On PowerShell set the project with
   `$env:GOOGLE_CLOUD_PROJECT='<project-id>'`; on POSIX shells use
   `export GOOGLE_CLOUD_PROJECT='<project-id>'` before running the tool.
5. Seed the sample catalog with `npm run seed:catalog -- --project <project-id>
   --dry-run` from `functions/`. Review the operations, then run the same command
   with `--apply` only against the intended development project or Emulator.
   Without `FIRESTORE_EMULATOR_HOST`, the script uses Application Default
   Credentials; it never needs a service-account file in the repo. It creates
   missing categories/products without overwriting edited documents. Old
   categories whose document ID differs from their key are copied to the
   canonical ID and hidden at the old ID. No document is deleted. If a category
   is inactive, its missing sample products are skipped. Verify `categories`
   IDs equal `name`, product `category` values reference active categories,
   and rerun `--dry-run` to confirm no further writes. Existing product seed
   helper is not called by the app.

## Local checks and Emulator

Use `npm ci` in `functions/` so the checked-in lockfile is honored. The exact
Flutter, backend and Firestore/Storage Emulator commands are in
[TESTING.md](TESTING.md); tests use the `demo-drink-app-p0-test` project ID.
No Firebase project or VNPay credential is needed for local unit/rules tests.

The Firestore product `price` is the S price. Both Flutter and the Function
read `functions/size_pricing.json`: M adds 5,000 VND and L adds 10,000 VND.
Changing offsets requires an app and Function release together. Orders store
the final unit price, name, size and quantity as a snapshot. Saved addresses
are local to the device under a UID-specific key; they do not sync across
devices. The cart is in memory and clears when the signed-in UID changes.
COD remains available without VNPay configuration. VNPay orders start with
`paymentStatus: pending` and `isPaid: false`; COD orders start `unpaid`.
Catalog rules require an active category document with ID equal to its key for
every product write. Checkout also checks this category before accepting an
order. Migrate legacy category IDs before editing their products.

## VNPay Sandbox configuration (manual; not performed here)

Official VNPay references:

- [PAY API 2.1.0 and payment URL](https://sandbox.vnpayment.vn/apis/docs/thanh-toan-pay/pay.html)
- [HMACSHA512, IPN and Return URL](https://sandbox.vnpayment.vn/apis/docs/chuyen-doi-thuat-toan/changeTypeHash.html)
- [QUERYDR request and response](https://sandbox.vnpayment.vn/apis/docs/truy-van-hoan-tien/querydr%26refund.html)
- [API 2.1.0 technical PDF](https://sandbox.vnpayment.vn/apis/files/VNPAY%20Payment%20Gateway_Techspec%202.1.0-VN.pdf)
- [FAQ](https://sandbox.vnpayment.vn/apis/docs/faqs/) and [response codes](https://sandbox.vnpayment.vn/apis/docs/bang-ma-loi/)

1. Obtain a new Sandbox merchant profile from VNPay. Store `VNPAY_TMN_CODE`
   and `VNPAY_HASH_SECRET` through Firebase Secret Manager:

   ```sh
   firebase functions:secrets:set VNPAY_TMN_CODE
   firebase functions:secrets:set VNPAY_HASH_SECRET
   ```

   Never copy their values into Flutter, `.env`, docs or CI. Do not reuse
   credentials from Git history.
2. Deploy vnpayIpn and vnpayReturn to a separate Firebase development project.
   Copy the actual HTTPS URLs and register the IPN and Return URL with VNPay
   for that merchant profile. The IPN accepts GET query parameters and returns
   JSON RspCode/Message. The Return URL cannot set paid.
3. Copy functions/.env.example to ignored functions/.env.<project-id>. Set
   VNPAY_IPN_URL, VNPAY_RETURN_URL and VNPAY_ORDER_TYPE accepted by your
   merchant profile; then set VNPAY_ENABLED=true. This file contains only
   nonsecret configuration. Deploy vnpayAvailability, createVnpayPayment and
   vnpayIpn with the Secret Manager bindings, along with COD and Admin
   Callables, rules and the matching app. Keep VNPay disabled until ready.
4. With a new Sandbox test account, check a small test order, the pending
   state, signed IPN, duplicate IPN, cancellation and app return. Confirm
   Firestore marks payment paid only after valid IPN or verified QUERYDR.
   This repository has not verified a real VNPay Sandbox transaction or real
   Firebase deployment.

The backend calculates amount from the saved order and signs vnp_Amount as
VND times 100 with API 2.1.0 HMACSHA512. It omits vnp_SecureHashType.
The reference is random and opaque, mapped to the order in server-only
Firestore documents. Flutter opens the URL in an external browser and reads
the order from Firestore. Tests use dummy credentials and never contact VNPay.

### Pending orders and QUERYDR

VNPAY_QUERY_ENABLED=false by default. The current VNPay web QUERYDR page
uses vnp_TransactionDate; the official 2.1.0 PDF labels the corresponding
field vnp_TransDate. Confirm the field required by your Sandbox merchant
profile and the exact signed response with VNPay before enabling QUERYDR.
Also configure VNPAY_SERVER_IP to the server egress IP accepted by VNPay.
When enabled, reconcileVnpayPayment requires the Admin custom claim, limits
queries to one per order every five minutes, verifies the response HMAC,
reference, amount and status, and records an audit. Network errors and unclear
results leave the order pending. Switching off new VNPay payments does not
disable IPN processing for existing pending orders.

If IPN does not arrive, leave the order pending, check the reference and amount
in the VNPay Sandbox merchant portal and contact VNPay support if needed.
Do not change paymentStatus directly in Firestore Console or Admin UI. A Return
URL hit, timeout or unsigned result is never proof of payment.
If a later signed success conflicts with a previously closed payment, the
backend keeps the closed state and returns a duplicate code. The owner must
resolve that discrepancy with VNPay; it must not be settled by a client edit.

## Admin menu, order flow and COD (manual release)

Categories keep an immutable `name` key. Admins can change their display name,
sort order and visibility, but rules reject hard deletion. Hiding a category
also stops selling its current products; showing it again does not automatically
reopen those products. New category document
IDs use the key; older seeded document IDs remain unchanged. Products select an
active category key in the Admin form. Archiving a product sets `isArchived: true`
and `isAvailable: false`; it does not delete its document or Storage image.
Storage accepts Admin JPEG uploads below 5 MB at
`products/<product-id>_<revision>.jpg` and rejects deletion. New image uploads
use a new path so older image references remain valid. Existing order item
snapshots retain their saved name,
size, unit price and quantity.

Order processing uses `orderStatus` (with legacy `status` mirrored for older
screens) and `paymentStatus` separately. Only the Admin-claim Callable
`updateOrderStatus` can advance pending → preparing → delivery → complete;
cancellation is allowed before completion unless payment is already collected.
VNPay orders cannot advance before signed IPN or verified QUERYDR confirms
payment, and a VNPay payment still pending cannot be cancelled by Admin.
An Admin confirms cash
receipt through `collectCodPayment` during delivery or after completion. The
Function writes `paidAt`, `paidBy`, `paymentStatus: paid` and one audit entry;
repeating the action is idempotent. Clients, including Admin clients, cannot
write order documents directly. Audit entries are readable only with Admin
claim. Grant and revoke claims only with the trusted tool above.

Deploy the Admin Callable Functions and Firestore rules together, then
release the updated app. Do not release the order update denial rule alone
while an old Admin app still writes `status` directly. Refresh Admin ID tokens
after changing claims. Verify an ordinary account cannot call either Function
or write catalog/order documents, and test one COD order through completion and
cash collection in a separate development Firebase project. Older orders with
no `paymentStatus` are intentionally excluded from the dashboard's collected
money metric until reconciled. No live Firebase project was used for these
changes.
