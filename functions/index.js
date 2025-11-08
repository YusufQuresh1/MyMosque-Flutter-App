/**
 * Firebase Cloud Functions for MyMosque App
 * 
 * Handles scheduled and real-time messaging for:
 * - New post notifications from mosques
 * - Scheduled prayer time reminders (start and jamaat)
 * - Direct notifications for actions like friend/affiliation requests
 * 
 * Features:
 * - Firestore trigger on new posts to notify followers
 * - Scheduled function (daily 00:30 Europe/London) to queue prayer notifications
 * - Uses Cloud Tasks for timed delivery of messages
 * - Secure HTTPS callable to trigger per-user scheduling on login
 * - Manual testing and debug endpoints included
 *
 * Dependencies:
 * - Firebase Admin SDK
 * - @google-cloud/tasks (for scheduling notifications)
 * - luxon (for timezone-aware datetime)
 * 
 * Region: europe-west2
 * Runtime: nodejs20
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { CloudTasksClient } = require("@google-cloud/tasks");

admin.initializeApp(); // Initialize Firebase Admin SDK to interact with Firestore and Messaging
const tasksClient = new CloudTasksClient(); // Used to programmatically create Cloud Tasks

/**
 * Triggered when a new post is created in Firestore (Posts/{postId})
 * 
 * This function identifies all users who follow the mosque that posted,
 * checks if they have enabled post notifications, and sends FCM push alerts.
 */
exports.sendPostNotification = functions
  .region("europe-west2")
  .runWith({ runtime: "nodejs20" }) // Define runtime environment
  .firestore
  .document("Posts/{postId}")
  .onCreate(async (snap) => {
    const post = snap.data();
    const mosqueId = post.mosqueId;

    try {
      // Step 1: Get all users from the database
      const usersSnapshot = await admin.firestore().collection("Users").get();
      const userIds = [];

      // Step 2: Filter only users who follow the mosque that posted
      for (const userDoc of usersSnapshot.docs) {
        const followDoc = await admin
          .firestore()
          .collection("Users")
          .doc(userDoc.id)
          .collection("FollowingMosques")
          .doc(mosqueId)
          .get();

        if (followDoc.exists) userIds.push(userDoc.id);
      }

      // Step 3: Collect FCM tokens for users who opted into post notifications
      const tokens = [];
      for (const uid of userIds) {
        const userRef = admin.firestore().collection("Users").doc(uid);
        const [userDoc, settingsDoc] = await Promise.all([
          userRef.get(),
          userRef.collection("NotificationSettings").doc(mosqueId).get()
        ]);

        const userData = userDoc.data();
        const settings = settingsDoc.exists ? settingsDoc.data() : null;

        const wantsPostNotif = settings?.posts === true;
        const fcmToken = userData?.fcmToken;

        if (wantsPostNotif && fcmToken) {
          tokens.push(fcmToken);
        }
      }

      // Step 4: Send the notification via FCM multicast
      if (!tokens.length) {
        console.log("No tokens found, skipping notification.");
        return;
      }

      const message = {
        notification: {
          title: `${post.mosqueName} posted`,
          body: post.message || "New announcement",
        },
        tokens,
      };

      await admin.messaging().sendEachForMulticast(message);
      console.log(`Notification sent to ${tokens.length} users`);
    } catch (error) {
      console.error("Error in sendPostNotification function:", error);
    }
  });

/**
 * HTTPS endpoint for manually triggering the prayer notification scheduler
 * 
 * This is useful for testing in development or triggering resends.
 * Internally it calls the same logic used in the auto-scheduler.
 */
exports.testSchedulePrayerNotifications = functions
  .region("europe-west2")
  .runWith({ runtime: "nodejs20" })
  .https.onRequest(async (req, res) => {
    try {
      await handlePrayerNotificationsSchedule();
      res.send("Manual prayer notification scheduler triggered.");
    } catch (error) {
      console.error("Error in manual prayer scheduler:", error);
      res.status(500).send("Internal Server Error: " + error.message);
    }
  });

  /**
 * Shared logic to handle scheduling all start/jamaat notifications
 * for all users and mosques for the current day.
 * 
 * This function is invoked by:
 * - The manual test endpoint
 * - The daily cron job at 00:30
 */
  async function handlePrayerNotificationsSchedule() {
    const londonNow = DateTime.now().setZone("Europe/London"); // ensure UK timezone
    const dateStr = londonNow.toFormat("yyyy-MM-dd"); // Firestore doc ID format
    const now = londonNow.toJSDate(); // for JS comparisons
  
    console.log("Running full prayer notification scheduler at", londonNow.toISO());
  
    const mosquesSnap = await admin.firestore().collection("Mosques").get();
  
    // Iterate over all mosques
    for (const mosqueDoc of mosquesSnap.docs) {
      const mosqueId = mosqueDoc.id;
      const mosqueName = mosqueDoc.data().name || "Your Mosque";
  
      const prayerDoc = await admin.firestore()
        .collection("Mosques")
        .doc(mosqueId)
        .collection("PrayerTimes")
        .doc(dateStr)
        .get();
  
      if (!prayerDoc.exists) continue;
  
      const prayerTimes = prayerDoc.data();

      // Loop through all users in system
      const usersSnap = await admin.firestore().collection("Users").get();
  
      for (const userDoc of usersSnap.docs) {
        const userId = userDoc.id;
        const token = userDoc.data()?.fcmToken;
        if (!token) continue;
  
        // Fetch this user's notification settings for this mosque
        const notifDoc = await admin.firestore()
          .collection("Users")
          .doc(userId)
          .collection("NotificationSettings")
          .doc(mosqueId)
          .get();
  
        if (!notifDoc.exists) continue;
  
        const prefs = notifDoc.data()?.prayer_notifications || {};
  
        // Schedule notifications for each prayer based on user preferences
        for (const [prayer, settings] of Object.entries(prefs)) {
          const timeObj = prayerTimes[prayer];
          if (!timeObj) continue;
  
          // Start time
          if (settings.start && timeObj.start?.toDate) {
            const startTime = timeObj.start.toDate();
            if (startTime > now) {
              await createNotificationTask({
                token,
                sendAt: startTime,
                title: mosqueName,
                body: `${capitalize(prayer)} at ${formatTime(startTime)}`,
                data: { type: "prayer", prayer, timeType: "start", mosqueName, mosqueId },
              });
            }
          }
  
          // Jamaat time (30 minutes before)
          if (settings.jamaat && timeObj.jamaat?.toDate) {
            const jamaatTime = timeObj.jamaat.toDate();
            jamaatTime.setMinutes(jamaatTime.getMinutes() - 30);
            if (jamaatTime > now) {
              await createNotificationTask({
                token,
                sendAt: jamaatTime,
                title: mosqueName,
                body: `${capitalize(prayer)} Jamaat in 30 mins`,
                data: { type: "prayer", prayer, timeType: "jamaat", mosqueName, mosqueId },
              });
            }
          }
        }
      }
    }
  
    console.log("Prayer notification scheduler completed.");
  }
  
/**
 * Schedules daily prayer notifications at 00:30 UK time for all users and mosques.
 * 
 * Uses Pub/Sub (cron) to invoke `handlePrayerNotificationsSchedule()` every day.
 */
exports.schedulePrayerNotifications = functions
  .region("europe-west2")
  .runWith({ runtime: "nodejs20" })
  .pubsub.schedule("every day 00:30") // UK time
  .timeZone("Europe/London")
  .onRun(handlePrayerNotificationsSchedule);

/**
 * Immediately sends a push notification to a single user.
 * 
 * This is invoked by the Cloud Task scheduler at the time a notification is due.
 * Expects token, title, body, and optional data payload in POST body.
 */
exports.sendPrayerNotification = functions
  .region("europe-west2")
  .runWith({ runtime: "nodejs20" })
  .https.onRequest(async (req, res) => {
    const { token, title, body, data } = req.body;
    if (!token || !title || !body) {
      return res.status(400).send("Missing required fields");
    }

    try {
      await admin.messaging().send({
        token,
        notification: { title, body },
        data,
      });
      res.status(200).send("Success");
    } catch (err) {
      console.error("Error sending prayer notification:", err);
      res.status(500).send("Failed");
    }
  });

/**
 * Schedules all prayer notifications for a specific user and their followed mosques.
 * 
 * Used by `scheduleTodayPrayerNotifications` (called from client after login).
 * Iterates through the user's mosque settings and uses `createNotificationTask()`.
 */
const { DateTime } = require("luxon");

async function handlePrayerNotificationsScheduleForUser(uid, token) {
  const londonNow = DateTime.now().setZone("Europe/London");
  const dateStr = londonNow.toFormat("yyyy-MM-dd");

  console.log("Scheduling for user", uid, "on", dateStr);

  // Load list of followed mosques
  const followingSnap = await admin.firestore()
    .collection("Users")
    .doc(uid)
    .collection("FollowingMosques")
    .get();

  for (const doc of followingSnap.docs) {
    const mosqueId = doc.id;

    const notifDoc = await admin.firestore()
      .collection("Users")
      .doc(uid)
      .collection("NotificationSettings")
      .doc(mosqueId)
      .get();

    if (!notifDoc.exists) continue;

    const prefs = notifDoc.data()?.prayer_notifications || {};

    const prayerDoc = await admin.firestore()
      .collection("Mosques")
      .doc(mosqueId)
      .collection("PrayerTimes")
      .doc(dateStr)
      .get();

    if (!prayerDoc.exists) continue;

    const prayerTimes = prayerDoc.data();
    const mosqueData = (await admin.firestore().collection("Mosques").doc(mosqueId).get()).data();
    const mosqueName = mosqueData?.name ?? "Your Mosque";

    for (const [prayer, settings] of Object.entries(prefs)) {
      const timeObj = prayerTimes[prayer];
      if (!timeObj) continue;

      // Start time
      if (settings.start && timeObj.start?.toDate) {
        const startTime = timeObj.start.toDate();
        if (startTime > new Date()) {
          await createNotificationTask({
            token,
            sendAt: startTime,
            title: mosqueName,
            body: `${capitalize(prayer)} at ${formatTime(startTime)}`,
            data: { type: "prayer", prayer, timeType: "start", mosqueName, mosqueId },
          });
        }
      }

      // Jamaat time (30 mins before)
      if (settings.jamaat && timeObj.jamaat?.toDate) {
        const jamaatTime = timeObj.jamaat.toDate();
        jamaatTime.setMinutes(jamaatTime.getMinutes() - 30);
        if (jamaatTime > new Date()) {
          await createNotificationTask({
            token,
            sendAt: jamaatTime,
            title: mosqueName,
            body: `${capitalize(prayer)} Jamaat in 30 mins`,
            data: { type: "prayer", prayer, timeType: "jamaat", mosqueName, mosqueId },
          });
        }
      }
    }
  }
}


/**
 * Schedules a Cloud Task to deliver a push notification at the desired future time.
 * 
 * If a task with the same ID already exists, it is skipped (ensures no duplicates).
 * 
 * Uses:
 * - A custom generated task ID based on prayer + user + time
 * - The `sendPrayerNotification` endpoint as the target
 */
const crypto = require("crypto");
const { v4: uuidv4 } = require("uuid");

async function createNotificationTask({ token, sendAt, title, body, data }) {
  try {
    const project = JSON.parse(process.env.FIREBASE_CONFIG).projectId;
    const location = "europe-west2";
    const queue = "prayerNotifications";
    const url = `https://${location}-${project}.cloudfunctions.net/sendPrayerNotification`;
    const parent = tasksClient.queuePath(project, location, queue);

    const tokenHash = crypto.createHash("sha256").update(token).digest("hex").slice(0, 12);
    const taskId = `${data.type}_${data.prayer}_${data.timeType}_${data.mosqueId}_${tokenHash}_${sendAt.getTime()}`;
    const taskName = `${parent}/tasks/${taskId}`;

    const task = {
      name: taskName,
      httpRequest: {
        httpMethod: "POST",
        url,
        headers: { "Content-Type": "application/json" },
        body: Buffer.from(JSON.stringify({ token, title, body, data })).toString("base64"),
      },
      scheduleTime: { seconds: Math.floor(sendAt.getTime() / 1000) },
    };

    // Try to create the task — skip if it already exists
    await tasksClient.createTask({ parent, task });
    console.log(`Task scheduled: ${title} at ${sendAt}`);
  } catch (err) {
    if (err.code === 6) {
      console.log("Task already exists, skipping.");
    } else {
      console.error("Error creating task:", err);
    }
  }
}

/**
 * Capitalizes the first letter of a string.
 * Example: 'fajr' => 'Fajr'
 */
function capitalize(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

/**
 * Formats a JS Date to 'HH:mm' using UK time
 * Example: 13:30
 */
function formatTime(date) {
  return date.toLocaleTimeString("en-GB", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
    timeZone: "Europe/London",
  });
}

/**
 * Sends a direct push notification to a single user immediately.
 * 
 * This is different from scheduled notifications. It is used for:
 * - Friend requests
 * - Affiliation request approvals
 * - Mosque application updates
 * 
 * Expects the following fields in the POST request body:
 * - `token`: the recipient's FCM token
 * - `title`: title of the notification
 * - `body`: body content of the notification
 * - `data`: optional map of key-value data (e.g. for routing or type flags)
 */
exports.sendDirectNotification = functions
  .region("europe-west2")
  .runWith({ runtime: "nodejs20" })
  .https.onRequest(async (req, res) => {
    const { token, title, body, data } = req.body;

    // Validate required fields
    if (!token || !title || !body) {
      return res.status(400).send("Missing required fields");
    }

    try {
      // Send notification immediately to the given token
      await admin.messaging().send({
        token,
        notification: { title, body },
        data,
      });
      res.status(200).send("Success");
    } catch (err) {
      console.error("Error sending direct notification:", err);
      res.status(500).send("Failed");
    }
  });

/**
 * Called from the client (e.g., right after login) to schedule today's
 * prayer notifications immediately for the current user.
 * 
 * Relies on the FCM token provided in the payload and the authenticated UID.
 */
exports.scheduleTodayPrayerNotifications = functions
  .region("europe-west2")
  .runWith({ runtime: "nodejs20" })
  .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) throw new functions.https.HttpsError("unauthenticated", "User not signed in.");

    const token = data.token;
    if (!token) throw new functions.https.HttpsError("invalid-argument", "Missing FCM token.");

    await handlePrayerNotificationsScheduleForUser(uid, token);
  });

  async function handlePrayerNotificationsScheduleForUser(uid, token) {
    const londonNow = DateTime.now().setZone("Europe/London");
    const dateStr = londonNow.toFormat("yyyy-MM-dd");
    const now = londonNow.toJSDate(); // used for time comparisons
  
    console.log("Scheduling for user", uid, "on", dateStr);
  
    const followingSnap = await admin.firestore()
      .collection("Users")
      .doc(uid)
      .collection("FollowingMosques")
      .get();
  
    for (const doc of followingSnap.docs) {
      const mosqueId = doc.id;
  
      const notifDoc = await admin.firestore()
        .collection("Users")
        .doc(uid)
        .collection("NotificationSettings")
        .doc(mosqueId)
        .get();
  
      if (!notifDoc.exists) continue;
  
      const prefs = notifDoc.data()?.prayer_notifications || {};
  
      const prayerDoc = await admin.firestore()
        .collection("Mosques")
        .doc(mosqueId)
        .collection("PrayerTimes")
        .doc(dateStr)
        .get();
  
      if (!prayerDoc.exists) continue;
  
      const prayerTimes = prayerDoc.data();
      const mosqueData = (await admin.firestore().collection("Mosques").doc(mosqueId).get()).data();
      const mosqueName = mosqueData?.name ?? "Your Mosque";
  
      for (const [prayer, settings] of Object.entries(prefs)) {
        const timeObj = prayerTimes[prayer];
        if (!timeObj) continue;
  
        // START
        if (settings.start && timeObj.start?.toDate) {
          const startTime = timeObj.start.toDate();
          if (startTime > now) {
            await createNotificationTask({
              token,
              sendAt: startTime,
              title: mosqueName,
              body: `${capitalize(prayer)} at ${formatTime(startTime)}`,
              data: { type: "prayer", prayer, timeType: "start", mosqueName, mosqueId },
            });
          }
        }
  
        // JAMAAT
        if (settings.jamaat && timeObj.jamaat?.toDate) {
          const jamaatTime = timeObj.jamaat.toDate();
          jamaatTime.setMinutes(jamaatTime.getMinutes() - 30);
          if (jamaatTime > now) {
            await createNotificationTask({
              token,
              sendAt: jamaatTime,
              title: mosqueName,
              body: `${capitalize(prayer)} Jamaat in 30 mins`,
              data: { type: "prayer", prayer, timeType: "jamaat", mosqueName, mosqueId },
            });
          }
        }
      }
    }
  }
  
