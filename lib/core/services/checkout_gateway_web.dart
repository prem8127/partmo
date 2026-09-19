import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'checkout_options.dart';

class RazorpayGateway {
  JSObject? _checkout;
  bool _completed = false;

  void open({
    required CheckoutOptions options,
    required void Function(String paymentId) onSuccess,
    required void Function(String message) onFailure,
    required void Function() onDismiss,
  }) {
    _completed = false;
    if (!globalContext.hasProperty('Razorpay'.toJS).toDart) {
      onFailure('Razorpay could not load. Check your connection and retry.');
      return;
    }

    final successHandler = ((JSObject response) {
      if (_completed) return;
      _completed = true;
      final paymentId =
          response.getProperty<JSString?>('razorpay_payment_id'.toJS)?.toDart;
      if (paymentId == null || paymentId.isEmpty) {
        onFailure('Razorpay did not return a payment reference.');
        return;
      }
      onSuccess(paymentId);
    }).toJS;

    final dismissHandler = (() {
      if (_completed) return;
      _completed = true;
      onDismiss();
    }).toJS;

    final jsOptions = <String, Object?>{
      'key': options.keyId,
      'amount': options.amountPaise,
      'currency': 'INR',
      'name': 'PartMo',
      'description': options.description,
      'handler': successHandler,
      'prefill': <String, Object?>{
        'name': options.customerName,
        'email': options.customerEmail,
        'contact': options.customerPhone,
      },
      'notes': <String, Object?>{
        'order_reference': options.orderReference,
      },
      'theme': <String, Object?>{'color': '#073B63'},
      'modal': <String, Object?>{
        'ondismiss': dismissHandler,
        'confirm_close': true,
      },
    }.jsify() as JSObject;

    try {
      final constructor =
          globalContext.getProperty<JSFunction>('Razorpay'.toJS);
      _checkout = constructor.callAsConstructor<JSObject>(jsOptions);
      _checkout!.getProperty<JSFunction>('open'.toJS).callAsFunction(_checkout);
    } catch (_) {
      _completed = true;
      onFailure('Razorpay Test Checkout could not be opened. Please retry.');
    }
  }

  void dispose() {}
}
