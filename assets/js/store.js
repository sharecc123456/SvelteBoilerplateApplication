import { writable } from "svelte/store";

export const storeSignatureFields = writable(new Set());
export const inputBoxClicked = writable(false);
export const start_search = writable(false);
export const add_template_modal = writable(false);
export const add_contact_modal = writable(false);
export const dashboard_filter_modal = writable(false);
export const user_guide_modal = writable(false);
export const has_unread_notification = writable(false);
export const count_unread_notification = writable(0);
export const isRecipientInFillMode = writable(false);
export const isRequestorInEditMode = writable(false);
export const isRequestorInReviewMode = writable(false);
