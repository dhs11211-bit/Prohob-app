const admin = require("firebase-admin/app");
admin.initializeApp();

const googleMapsProxy = require("./google_maps_proxy.js");
exports.googleMapsProxy = googleMapsProxy.googleMapsProxy;
const syncClockInToAWS = require("./sync_clock_in_to_a_w_s.js");
exports.syncClockInToAWS = syncClockInToAWS.syncClockInToAWS;
const notifyAdminOnJobPending = require("./notify_admin_on_job_pending.js");
exports.notifyAdminOnJobPending =
  notifyAdminOnJobPending.notifyAdminOnJobPending;
