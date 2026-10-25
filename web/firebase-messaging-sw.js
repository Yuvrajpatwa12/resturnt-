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

// Handle background messages with safe null checks
messaging.onBackgroundMessage((payload) => {
  console.log("FCM: Received background message ", payload);
  if (!payload) return;

  const title = (payload.notification && payload.notification.title)
      || (payload.data && payload.data.title)
      || "Chiyabreak Notification";

  const body = (payload.notification && payload.notification.body)
      || (payload.data && payload.data.message)
      || "";

  const notificationOptions = {
    body: body,
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    tag: payload.messageId || "chiyabreak-notification",
    data: {
      url: (payload.fcmOptions && payload.fcmOptions.link)
          || (payload.data && (payload.data.url || payload.data.link))
          || "/"
    }
  };

  return self.registration.showNotification(title, notificationOptions);
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.stopImmediatePropagation();

  const requestedUrl = event.notification.data && event.notification.data.url;
  let targetUrl = new URL("/", self.location.origin);
  if (requestedUrl) {
    const candidate = new URL(requestedUrl, self.location.origin);
    if (candidate.origin === self.location.origin) {
      targetUrl = candidate;
    }
  }

  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true })
      .then((clients) => {
        for (const client of clients) {
          if (new URL(client.url).origin === self.location.origin) {
            return client.navigate(targetUrl.href)
              .then((windowClient) => (windowClient || client).focus());
          }
        }
        return self.clients.openWindow(targetUrl.href);
      })
  );
});
