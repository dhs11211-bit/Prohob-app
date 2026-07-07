const functions = require("firebase-functions");
const admin = require("firebase-admin");
// To avoid deployment errors, do not call admin.initializeApp() in your code
const https = require("https");

exports.googleMapsProxy = functions.https.onCall((data, context) => {
  return new Promise((resolve, reject) => {
    // ⚠️ PON TU LLAVE REAL DE GOOGLE CLOUD AQUÍ:
    const key = "AIzaSyCCepBRzPsX3M20vK0YTX5KINtZCiPkvYE";
    let url = "";

    if (data.action === "autocomplete") {
      const query = encodeURIComponent(data.query);
      url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${query}&key=${key}`;
    } else if (data.action === "details") {
      url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${data.placeId}&fields=geometry&key=${key}`;
    } else {
      reject(
        new functions.https.HttpsError("invalid-argument", "Acción no válida"),
      );
      return;
    }

    https
      .get(url, (res) => {
        let body = "";
        res.on("data", (chunk) => (body += chunk));
        res.on("end", () => resolve(JSON.parse(body)));
      })
      .on("error", (e) =>
        reject(new functions.https.HttpsError("internal", e.message)),
      );
  });
});
