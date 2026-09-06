importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDJxvus3o3x5BbRZw1Y_H-6hK1apH7niVI",
  authDomain: "startupsgo-resturnet.firebaseapp.com",
  projectId: "startupsgo-resturnet",
  storageBucket: "startupsgo-resturnet.firebasestorage.app",
  messagingSenderId: "849974618729",
  appId: "1:849974618729:web:050c0267d9ee9fff8a10f8",
  measurementId: "G-4X4YQCX07F"
});

const messaging = firebase.messaging();

// Optional: Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log("FCM: Received background message ", payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/favicon.png"
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
