// Temporary runtime flags for backend rollout gaps.
// Registration plan payment can stay bypassed until that API path is stable.
const bool kBypassPaymentsForNow = true;

// Booking payment must go through Razorpay checkout on confirm.
// Keep this false in production so user confirm always opens Razorpay.
const bool kBypassBookingPaymentsForNow = false;
