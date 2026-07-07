const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Inicializa admin si no lo han hecho globalmente
if (!admin.apps.length) {
  admin.initializeApp();
}

exports.notifyAdminOnJobPending = functions.https.onCall(
  async (data, context) => {
    const clientName = data.clientName || "a client";

    // Buscamos a los admins en la base de datos
    const adminsSnapshot = await admin
      .firestore()
      .collection("users")
      .where("role", "==", "admin")
      .get();

    if (adminsSnapshot.empty) {
      console.log("No admins found to notify.");
      return { success: false, message: "No admins found" };
    }

    // Juntamos los tokens de los celulares de los admins
    const tokens = [];
    adminsSnapshot.forEach((doc) => {
      const adminData = doc.data();
      if (adminData.fcm_tokens && adminData.fcm_tokens.length > 0) {
        tokens.push(...adminData.fcm_tokens);
      } else if (adminData.fcm_token) {
        tokens.push(adminData.fcm_token);
      }
    });

    if (tokens.length === 0) {
      return { success: false, message: "No tokens found" };
    }

    // Armamos la notificación push
    const payload = {
      notification: {
        title: "⚠️ Job requires approval!",
        body: `The job for ${clientName} has been completed and is awaiting your review.`,
        sound: "default",
      },
    };

    // Disparamos la notificación a los celulares
    try {
      await admin.messaging().sendToDevice(tokens, payload);
      return { success: true, message: "Notification sent successfully" };
    } catch (error) {
      console.error("Error sending notification:", error);
      return { success: false, error: error.message };
    }
  },
);
