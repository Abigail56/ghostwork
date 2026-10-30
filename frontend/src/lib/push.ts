import { api } from "./api";

export function pushSupported() {
  return typeof window !== "undefined" && "serviceWorker" in navigator && "PushManager" in window && "Notification" in window;
}

function keyToBytes(key: string) {
  const base64 = (key + "=".repeat((4 - (key.length % 4)) % 4)).replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
}

export async function currentSubscription() {
  const registration = await navigator.serviceWorker.getRegistration("/");
  return (await registration?.pushManager.getSubscription()) ?? null;
}

/** Ask permission, subscribe this browser and register it with the API. */
export async function enablePush(publicKey: string) {
  const permission = await Notification.requestPermission();
  if (permission !== "granted") throw new Error("Notifications are blocked for this site. Allow them in your browser settings.");
  const registration = await navigator.serviceWorker.register("/sw.js");
  await navigator.serviceWorker.ready;
  // Some browsers (private windows, for example) never settle this promise.
  const subscription = await Promise.race([
    registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: keyToBytes(publicKey) }),
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error("This browser's push service didn't respond. Private windows don't support push.")), 90_000),
    ),
  ]);
  const json = subscription.toJSON();
  await api("/push/subscriptions", { method: "POST", body: { kind: "webpush", endpoint: subscription.endpoint, keys: json.keys } });
}

export async function disablePush() {
  const subscription = await currentSubscription();
  if (!subscription) return;
  await api("/push/subscriptions", { method: "DELETE", body: { endpoint: subscription.endpoint } });
  await subscription.unsubscribe();
}
