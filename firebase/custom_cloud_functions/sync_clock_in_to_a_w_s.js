const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

// Solo inicializamos si no se ha hecho antes
if (!admin.apps.length) {
  admin.initializeApp();
}

exports.syncClockInToAWS = functions.firestore
  .document("time_logs/{logId}")
  .onCreate(async (snap, context) => {
    const newLog = snap.data();
    const logId = context.params.logId;

    const payloadToAWS = {
      firebase_log_id: logId,
      worker_id: newLog.worker_id,
      job_id: newLog.job_id,
      clock_in_time: newLog.clock_in
        ? newLog.clock_in.toDate().toISOString()
        : null,
      date_string: newLog.date_string,
      latitude: newLog.start_location ? newLog.start_location.latitude : null,
      longitude: newLog.start_location ? newLog.start_location.longitude : null,
    };

    try {
      // 🚀 AQUÍ VA LA URL QUE TE DEN LOS DE AWS
      const awsEndpoint = "https://tu-servidor-en-aws.com/api/sync-time-logs";

      const response = await axios.post(awsEndpoint, payloadToAWS, {
        headers: {
          "Content-Type": "application/json",
          "x-api-key": "TU_CLAVE_SECRETA_SUPER_SEGURA",
        },
      });

      console.log(`¡Éxito! Log ${logId} enviado a AWS.`);
      return null;
    } catch (error) {
      console.error(`¡Fallo en el puente a AWS para el log ${logId}:`, error);
      return null;
    }
  });
