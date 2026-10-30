// GhostWork service worker: shows push notifications and opens their link when clicked.
self.addEventListener("push", (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch {
    data = { title: "GhostWork", body: event.data ? event.data.text() : "" };
  }
  event.waitUntil(
    self.registration.showNotification(data.title || "GhostWork", {
      body: data.body || "",
      icon: "/ghostwork-mark.svg",
      data: { link: data.link || "/dashboard" },
    }),
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  // Links come from our own API, but only ever open a path on this site.
  const link = String(event.notification.data?.link || "/dashboard");
  const path = link.startsWith("/") && !link.startsWith("//") ? link : "/dashboard";
  event.waitUntil(self.clients.openWindow(path));
});
