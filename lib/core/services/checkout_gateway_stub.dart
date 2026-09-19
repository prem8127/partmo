import 'checkout_options.dart';

class RazorpayGateway {
  void open({
    required CheckoutOptions options,
    required void Function(String paymentId) onSuccess,
    required void Function(String message) onFailure,
    required void Function() onDismiss,
  }) {
    onFailure('Razorpay Test Checkout is currently available on the web app.');
  }

  void dispose() {}
}
