// Entry point — re-exports every callable/trigger so the Firebase CLI
// discovers them via `lib/index.js`. Keep this file free of business logic.

import './lib/firebase'; // initialize admin SDK once at cold start

export { ping } from './ping';
export { bootstrapSuperadminRole } from './role/bootstrapSuperadminRole';
export { setUserRole } from './role/setUserRole';
export { broadcastNotification } from './broadcast/broadcastNotification';
export { scheduleBroadcast } from './broadcast/scheduleBroadcast';
export { cancelScheduledBroadcast } from './broadcast/cancelScheduledBroadcast';
export { dispatchScheduledNotifications } from './scheduled/dispatchScheduledNotifications';
