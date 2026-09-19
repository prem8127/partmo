import 'package:razorpay_flutter/razorpay_flutter.dart' as rz;

import 'checkout_options.dart';

class RazorpayGateway {
  RazorpayGateway() {
    _razorpay.on(rz.Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(rz.Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(rz.Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  final _razorpay = rz.Razorpay();
  void Function(String paymentId)? _onSuccess;
  void Function(String message)? _onFailure;
  void Function()? _onDismiss;
  bool _completed = false;

  void open({
    required CheckoutOptions options,
    required void Function(String paymentId) onSuccess,
    required void Function(String message) onFailure,
    required void Function() onDismiss,
  }) {
    _completed = false;
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    _onDismiss = onDismiss;

    try {
      _razorpay.open({
        'key': options.keyId,
        'amount': options.amountPaise,
        'currency': 'INR',
        'name': 'PartMo',
        'description': options.description,
        'prefill': {
          'name': options.customerName,
          'email': options.customerEmail,
          'contact': options.customerPhone,
        },
        'notes': {
          'order_reference': options.orderReference,
        },
        'theme': {'color': '#073B63'},
      });
    } catch (_) {
      _completed = true;
      onFailure('Razorpay Checkout could not be opened. Please retry.');
    }
  }

  void _handleSuccess(rz.PaymentSuccessResponse response) {
    if (_completed) return;
    _completed = true;
    final paymentId = response.paymentId;
    if (paymentId == null || paymentId.isEmpty) {
      _onFailure?.call('Razorpay did not return a payment reference.');
      return;
    }
    _onSuccess?.call(paymentId);
  }

  void _handleError(rz.PaymentFailureResponse response) {
    if (_completed) return;
    _completed = true;
    if (response.code == rz.Razorpay.PAYMENT_CANCELLED) {
      _onDismiss?.call();
      return;
    }
    final message = response.message?.trim();
    if (message == null || message.isEmpty) {
      _onFailure?.call('Razorpay payment could not be completed.');
      return;
    }
    _onFailure?.call(message);
  }

  void _handleExternalWallet(rz.ExternalWalletResponse response) {}

  void dispose() {
    _razorpay.clear();
  }
}
