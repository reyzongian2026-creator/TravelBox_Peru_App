class PaymentConstants {
  static const methodCard = 'card';
  static const methodYape = 'yape';
  static const methodWallet = 'wallet';
  static const methodCounter = 'counter';
  static const methodCash = 'cash';

  static const digitalMethods = <String>{methodCard, methodYape, methodWallet};

  static const offlineMethods = <String>{methodCounter, methodCash};

  static bool isOffline(String method) =>
      offlineMethods.contains(method.trim().toLowerCase());
}
