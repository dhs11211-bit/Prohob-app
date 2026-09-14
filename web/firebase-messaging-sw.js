importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCtUmbGv4iB3auEdmwyMesDzYUIe-UV93c",
  appId: "1:7390119917:web:89389a7765342053d689e4",
  messagingSenderId: "7390119917",
  projectId: "prohob-pusher",
  authDomain: "prohob-pusher.firebaseapp.com",
  storageBucket: "prohob-pusher.firebasestorage.app",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification ? payload.notification.title : 'Notification';
  const notificationOptions = {
    body: payload.notification ? payload.notification.body : '',
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
