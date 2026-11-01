class OrderStatus {
  OrderStatus._();

  static const pending = 'Pending';
  static const processing = 'Processing';
  static const outForDelivery = 'OutForDelivery';
  static const waitingForRider = 'WaitingForRider';
  static const readyForPickup = 'ReadyForPickup';
  static const completed = 'Completed';
  static const cancelled = 'Cancelled';
}